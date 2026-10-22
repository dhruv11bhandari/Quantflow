import SwiftUI

/// "+12 XP" with a small particle burst. Sits in an overlay so it never changes layout.
struct XPBurst: View {
    let amount: Int
    @State private var go = false

    private func spread(_ i: Int) -> CGSize {
        let angle = Double(i) * 0.628
        let radius: CGFloat = go ? 42 : 0
        return CGSize(width: CGFloat(cos(angle)) * radius, height: CGFloat(sin(angle)) * radius)
    }

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 5, height: 5)
                    .offset(x: spread(i).width, y: spread(i).height)
                    .opacity(go ? 0.0 : 1.0)
            }
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill").qf(13, .bold)
                Text("+\(amount) XP").qf(17, .bold, design: .rounded, relativeTo: .headline)
            }
            .foregroundStyle(Theme.accent)
            .scaleEffect(go ? 1.0 : 0.6)
            .opacity(go ? 1.0 : 0.0)
        }
        .frame(width: 110, height: 40)
        .onAppear {
            if Motion.reduced {
                go = true
            } else {
                withAnimation(Animation.easeOut(duration: 0.8)) { go = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plus \(amount) experience points")
    }
}

/// Opening animation: maths symbols drift, then converge into the nine letters of QUANTFLOW.
struct SplashBackdrop: View {
    let elapsed: Double
    let letterStep: CGFloat
    let titleY: CGFloat

    static let symbols = ["Σ", "π", "E[X]", "P(A|B)", "√", "∫", "Δ", "μ", "σ"]
    private static let dust = ["∞", "≈", "%", "∂", "λ", "θ", "ρ", "Φ", "ε", "Ω", "β", "∑", "≠", "±"]

    /// 0 → 1 while the symbols travel to the wordmark.
    static func converge(_ t: Double) -> Double {
        let c = clamp((t - 1.3) / 1.7, 0, 1)
        return c * c * (3 - 2 * c)
    }

    private func fract(_ x: Double) -> Double { x - x.rounded(.down) }

    var body: some View {
        Canvas { context, size in
            let e = SplashBackdrop.converge(elapsed)
            let reduce = Platform.reduceMotion
            let t = reduce ? 0.0 : elapsed
            var rng = SeededRNG(seed: 77)
            let mainCount = SplashBackdrop.symbols.count

            for (i, symbol) in SplashBackdrop.symbols.enumerated() {
                let u = rng.double()
                let v = rng.double()
                let speed = 0.006 + 0.004 * Double(i % 4)
                let driftX = CGFloat(fract(u + speed * t)) * size.width
                let driftY = CGFloat(v) * size.height * 0.9 + CGFloat(sin(t * 0.5 + Double(i))) * 14
                let slotX = size.width / 2 + CGFloat(i - mainCount / 2) * letterStep
                let slotY = titleY
                let k = CGFloat(e)
                let x = driftX + (slotX - driftX) * k
                let y = driftY + (slotY - driftY) * k
                let fade = 1.0 - clamp((e - 0.9) / 0.1, 0, 1)
                context.opacity = 0.85 * fade
                let label = Text(symbol).font(Font.system(size: 22 + 6 * CGFloat(e), weight: .medium, design: .serif)).foregroundColor(Theme.accent)
                context.draw(label, at: CGPoint(x: x, y: y))
            }

            for (j, symbol) in SplashBackdrop.dust.enumerated() {
                let u = rng.double()
                let v = rng.double()
                let x = CGFloat(fract(u + 0.004 * t * Double(1 + j % 3))) * size.width
                let y = CGFloat(v) * size.height + CGFloat(cos(t * 0.35 + Double(j))) * 10
                context.opacity = 0.20 * (1.0 - e)
                let label = Text(symbol).font(Font.system(size: 20, weight: .regular, design: .serif)).foregroundColor(Theme.textDim)
                context.draw(label, at: CGPoint(x: x, y: y))
            }
        }
        .accessibilityHidden(true)
    }
}
