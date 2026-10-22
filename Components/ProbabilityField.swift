import SwiftUI

/// Particle state for the Probability Field. A reference type so the Canvas renderer can advance it every frame.
final class FieldSim {
    struct Particle {
        var x: CGFloat
        var y: CGFloat
        let u: CGFloat
        let v: CGFloat
        let phase: Double
    }

    var particles: [Particle] = []
    var lastTime: Double = 0
    var ready = false

    init(count: Int) {
        var rng = SeededRNG(seed: 20_260_907)
        for _ in 0..<count {
            particles.append(Particle(x: 0, y: 0, u: CGFloat(rng.double()), v: CGFloat(rng.double()), phase: rng.double() * 6.28))
        }
    }

    /// Home position of particle i: the left bin holds misses, the right bin holds hits.
    func home(_ i: Int, success: Bool, size: CGSize) -> CGPoint {
        let p = particles[i]
        let pad: CGFloat = 10
        let gap: CGFloat = 18
        let w = (size.width - gap - 2 * pad) / 2
        let h = size.height - 2 * pad
        let x0 = success ? pad + w + gap : pad
        return CGPoint(x: x0 + p.u * w, y: pad + p.v * h)
    }

    func step(now: Double, size: CGSize, successCount: Int, snap: Bool) {
        let dt = lastTime == 0 ? 0.016 : clamp(now - lastTime, 0.0, 0.1)
        lastTime = now
        let k = CGFloat(1.0 - exp(-dt * 5.5))
        for i in 0..<particles.count {
            let h = home(i, success: i < successCount, size: size)
            if snap {
                particles[i].x = h.x
                particles[i].y = h.y
            } else if !ready {
                // First frame: scatter across the whole field, then flow into the two bins.
                particles[i].x = particles[i].u * size.width
                particles[i].y = particles[i].v * size.height
            } else {
                particles[i].x += (h.x - particles[i].x) * k
                particles[i].y += (h.y - particles[i].y) * k
            }
        }
        ready = true
    }
}

/// 200 simulated outcomes. P of them move into the HIT bin — probability you can *see*.
struct ProbabilityField: View {
    let probability: Double
    var height: CGFloat = 150
    private let total = 200
    @State private var sim = FieldSim(count: 200)
    private var hits: Int { Int((clamp(probability, 0, 1) * Double(200)).rounded()) }
    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    sim.step(now: t, size: size, successCount: hits, snap: Platform.reduceMotion)
                    drawParticles(&context, size: size, t: t)
                }
            }
            .frame(height: height)
            .background { RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.bgRaised) }
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1) }
            HStack {
                Text("MISS · \(total - hits)").qfLabel()
                Spacer()
                Text("HIT · \(hits)").qfLabel(Theme.accent)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Probability field")
        .accessibilityValue("\(hits) of \(total) simulated outcomes are hits. Probability \(Fmt.num(probability, maxDecimals: 3)).")
    }
    private func drawParticles(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        let wobble = !Platform.reduceMotion
        for i in 0..<sim.particles.count {
            let p = sim.particles[i]
            let isHit = i < hits
            let dx: CGFloat = wobble ? CGFloat(sin(t * 1.3 + p.phase)) * 1.6 : 0
            let dy: CGFloat = wobble ? CGFloat(cos(t * 1.1 + p.phase)) * 1.6 : 0
            let r: CGFloat = isHit ? 3.3 : 2.4
            let rect = CGRect(x: p.x + dx - r, y: p.y + dy - r, width: r * 2, height: r * 2)
            let color: Color = isHit ? Theme.accent : Theme.textDim.opacity(0.55)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }
}
