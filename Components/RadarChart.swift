import SwiftUI

private func polar(_ c: CGPoint, _ r: CGFloat, _ a: Double) -> CGPoint {
    CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
}

/// Axis i of n, starting at 12 o'clock and going clockwise.
private func axisAngle(_ i: Int, _ n: Int) -> Double {
    -Double.pi / 2 + 2 * Double.pi * Double(i) / Double(max(n, 1))
}

struct RadarGrid: Shape {
    let sides: Int
    let rings: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard sides >= 3, rings >= 1 else { return p }
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for ring in 1...rings {
            let rr = r * CGFloat(ring) / CGFloat(rings)
            for i in 0..<sides {
                let pt = polar(c, rr, axisAngle(i, sides))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
        for i in 0..<sides {
            p.move(to: c)
            p.addLine(to: polar(c, r, axisAngle(i, sides)))
        }
        return p
    }
}

struct RadarShape: Shape {
    var values: [Double]
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let n = values.count
        guard n >= 3 else { return p }
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<n {
            let radius = r * CGFloat(values[i]) * progress
            let pt = polar(c, radius, axisAngle(i, n))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Spider chart of the seven skills. Values are 0–100. The accessible summary lists every number.
struct RadarChart: View {
    let skills: [SkillKey]
    let values: [Double]
    var animateIn = true
    @State private var progress: CGFloat = 0

    private var normalized: [Double] { values.map { clamp($0, 0, 100) / 100 } }

    private var summary: String {
        var parts: [String] = []
        for (i, s) in skills.enumerated() where i < values.count { parts.append("\(s.name) \(Int(values[i].rounded()))") }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = side * 0.34
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                RadarGrid(sides: skills.count, rings: 4)
                    .stroke(Theme.line, lineWidth: 1)
                    .frame(width: radius * 2, height: radius * 2)
                RadarShape(values: normalized, progress: progress)
                    .fill(LinearGradient(colors: [Theme.accent.opacity(0.40), Theme.blue.opacity(0.16)], startPoint: .top, endPoint: .bottom))
                    .frame(width: radius * 2, height: radius * 2)
                RadarShape(values: normalized, progress: progress)
                    .stroke(Theme.accent, lineWidth: 2)
                    .frame(width: radius * 2, height: radius * 2)
                ForEach(0..<skills.count, id: \.self) { i in
                    axisLabel(i, center: center, radius: radius)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            if animateIn {
                withAnimation(Motion.slow) { progress = 1 }
            } else {
                progress = 1
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Skill radar chart")
        .accessibilityValue(summary)
    }

    private func axisLabel(_ i: Int, center: CGPoint, radius: CGFloat) -> some View {
        let pt = polar(center, radius * 1.34, axisAngle(i, skills.count))
        let v = i < values.count ? Int(values[i].rounded()) : 0
        return VStack(spacing: 1) {
            Text(skills[i].short).qfLabel(Theme.textDim)
            Text("\(v)").qf(13, .bold, design: .monospaced, relativeTo: .caption).foregroundStyle(Theme.text)
        }
        .position(x: pt.x, y: pt.y)
    }
}
