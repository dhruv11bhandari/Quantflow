import SwiftUI

struct ProgressBar: View {
    let value: Double
    var height: CGFloat = 6
    var tint: Color = Theme.accent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceHigh)
                Capsule().fill(tint)
                    .frame(width: max(height, geo.size.width * CGFloat(clamp(value, 0, 1))))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// "████████░░░░" daily-goal meter.
struct SegmentMeter: View {
    let filled: Int
    let total: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(i < filled ? Theme.accent : Theme.surfaceHigh)
                    .frame(height: 8)
            }
        }
        .animation(Motion.quick, value: filled)
        .accessibilityHidden(true)
    }
}

/// Circular gauge with a round-capped arc.
struct RingGauge: View {
    let progress: Double
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle().stroke(Theme.surfaceHigh, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(clamp(progress, 0, 1)))
                .stroke(AngularGradient(colors: [Theme.blue, Theme.accent], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}

/// A number that counts up smoothly when its value is animated.
struct CountUp: View, Animatable {
    var value: Double
    var suffix: String = ""

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))\(suffix)").monospacedDigit()
    }
}

/// One skill: name, bar, number. Meaning is carried by the number as well as the bar length.
struct SkillBarRow: View {
    let name: String
    let value: Double
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).qfLabel(Theme.text)
                Spacer()
                Text("\(Int(value.rounded()))").qf(15, .bold, design: .monospaced, relativeTo: .body).foregroundStyle(Theme.text)
            }
            ProgressBar(value: value / 100, height: 6, tint: tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name)")
        .accessibilityValue("\(Int(value.rounded())) out of 100")
    }
}
