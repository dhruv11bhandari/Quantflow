import SwiftUI

/// First screen: maths symbols drift, then converge into the QUANTFLOW wordmark.
struct SplashView: View {
    let hasProfile: Bool
    let onStart: () -> Void
    let onDemo: () -> Void

    @State private var start = Date()
    private let letters: [String] = ["Q", "U", "A", "N", "T", "F", "L", "O", "W"]

    var body: some View {
        GeometryReader { geo in
            let step = min(geo.size.width / 10.5, 44)
            let titleY = geo.size.height * 0.34
            TimelineView(.animation) { timeline in
                let t: Double = Motion.reduced ? 6.0 : timeline.date.timeIntervalSince(start)
                let e = SplashBackdrop.converge(t)
                ZStack {
                    SplashBackdrop(elapsed: t, letterStep: step, titleY: titleY)
                    glow(e: e, step: step).position(x: geo.size.width / 2, y: titleY)
                    wordmark(step: step, e: e).position(x: geo.size.width / 2, y: titleY)
                    tagline(t: t, step: step).position(x: geo.size.width / 2, y: titleY + step * 2.6)
                    VStack(spacing: 14) {
                        Spacer()
                        controls(t: t)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                    .qfColumn(520)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { skipAhead() }
    }

    private func skipAhead() {
        if Date().timeIntervalSince(start) < 3.4 { start = Date().addingTimeInterval(-3.4) }
    }

    private func letterAlpha(_ i: Int, _ e: Double) -> Double {
        clamp((e - (0.78 + 0.02 * Double(i))) / 0.12, 0, 1)
    }

    private func wordmark(step: CGFloat, e: Double) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<letters.count, id: \.self) { i in
                Text(letters[i])
                    .font(Font.system(size: step * 1.22, weight: .bold, design: .monospaced))
                    .foregroundStyle(i >= 5 ? Theme.accent : Theme.text)
                    .frame(width: step)
                    .opacity(letterAlpha(i, e))
                    .scaleEffect(0.92 + 0.08 * CGFloat(letterAlpha(i, e)))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("QuantFlow")
        .accessibilityAddTraits(.isHeader)
    }

    private func glow(e: Double, step: CGFloat) -> some View {
        let peak = clamp(1.0 - abs(e - 0.96) / 0.1, 0, 1)
        return Circle()
            .fill(RadialGradient(colors: [Theme.accent.opacity(0.45 * peak), Color.clear], center: .center, startRadius: 0, endRadius: step * 6))
            .frame(width: step * 12, height: step * 12)
            .accessibilityHidden(true)
    }

    private func tagline(t: Double, step: CGFloat) -> some View {
        let lines = ["Train your brain.", "Think faster.", "Trade smarter."]
        return VStack(spacing: 4) {
            ForEach(0..<lines.count, id: \.self) { i in
                let a = clamp((t - (2.9 + 0.3 * Double(i))) / 0.4, 0, 1)
                Text(lines[i])
                    .qf(19, i == 2 ? .semibold : .regular, relativeTo: .title3)
                    .foregroundStyle(i == 2 ? Theme.accent : Theme.textDim)
                    .opacity(a)
                    .offset(y: CGFloat(1 - a) * 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Train your brain. Think faster. Trade smarter.")
    }

    private func controls(t: Double) -> some View {
        let a = clamp((t - 3.4) / 0.5, 0, 1)
        return VStack(spacing: 14) {
            PrimaryButton(title: hasProfile ? "CONTINUE TRAINING" : "ENTER THE GYM", symbol: "arrow.right", enabled: a > 0.3, action: onStart)
            Button(action: { Haptics.select(); onDemo() }) {
                Text(hasProfile ? "Explore the demo profile instead" : "Explore demo profile")
                    .qf(14, .medium, relativeTo: .subheadline)
                    .foregroundStyle(Theme.textDim)
                    .padding(.vertical, 6)
            }
            .buttonStyle(PressStyle())
            .accessibilityHint("Loads a sample profile so you can explore every screen immediately.")
            Text("Educational simulation · Works offline · No account")
                .qfLabel(Theme.textDim.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .opacity(a)
    }
}
