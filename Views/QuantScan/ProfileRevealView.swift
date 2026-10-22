import SwiftUI

/// The reveal after QuantScan: score counts up, the radar grows, bars fill in one by one.
struct ProfileRevealView: View {
    let result: ScanResult?
    let onContinue: () -> Void

    @State private var shown: Double = 0
    @State private var barsIn = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if let r = result {
                content(r)
            } else {
                PrimaryButton(title: "CONTINUE", action: onContinue).padding(24)
            }
        }
        .qfColumn()
        .onAppear {
            withAnimation(Motion.slow) { shown = Double(result?.readiness ?? 0) }
            withAnimation(Motion.spring) { barsIn = true }
        }
    }

    private func content(_ r: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("YOUR QUANT PROFILE").qfLabel(Theme.accent).padding(.top, 28)
            gauge(r)
            VStack(spacing: 4) {
                Text("QuantFlow Training Score").qf(15, .semibold, relativeTo: .subheadline).foregroundStyle(Theme.text)
                Text("Training score, not a hiring prediction.").qf(13, .regular, relativeTo: .footnote).foregroundStyle(Theme.textDim)
            }
            .frame(maxWidth: .infinity)
            RadarChart(skills: SkillKey.allCases, values: SkillKey.allCases.map { r.skills[$0] })
                .frame(height: 300)
            VStack(spacing: 14) {
                ForEach(0..<SkillKey.allCases.count, id: \.self) { i in
                    let key = SkillKey.allCases[i]
                    SkillBarRow(name: key.title, value: r.skills[key])
                        .opacity(barsIn ? 1 : 0)
                        .offset(y: barsIn ? 0 : 12)
                        .animation(Motion.spring?.delay(0.08 * Double(i)), value: barsIn)
                }
            }
            .qfCard(padding: 18, radius: 22)
            edgeCard(r)
            HStack(spacing: 12) {
                StatTile(value: Fmt.percent(r.accuracy), caption: "ACCURACY")
                StatTile(value: Fmt.num(r.avgSeconds, maxDecimals: 1) + " sec", caption: "AVG RESPONSE")
            }
            PrimaryButton(title: "ENTER YOUR FEED", symbol: "arrow.right", action: onContinue)
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 22)
    }

    private func gauge(_ r: ScanResult) -> some View {
        ZStack {
            RingGauge(progress: shown / 100, lineWidth: 14)
            VStack(spacing: 2) {
                CountUp(value: shown)
                    .qf(84, .bold, design: .rounded, relativeTo: .largeTitle)
                    .foregroundStyle(Theme.text)
                Text("QUANT READINESS").qfLabel()
            }
        }
        .frame(width: 230, height: 230)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quant readiness")
        .accessibilityValue("\(r.readiness) out of 100")
    }

    private func edgeCard(_ r: ScanResult) -> some View {
        let conceptual = r.mistakes[MistakeCategory.conceptual.rawValue] ?? 0
        let slow = r.mistakes[MistakeCategory.slow.rawValue] ?? 0
        var note = "Your feed starts here."
        if conceptual > 0 { note = "\(conceptual) fast-and-wrong answer\(conceptual == 1 ? "" : "s"): those are concept gaps, so they come back for review." }
        else if slow > 0 { note = "\(slow) correct answer\(slow == 1 ? " was" : "s were") slow. Speed work comes first." }
        return VStack(alignment: .leading, spacing: 8) {
            Text("YOUR NEXT EDGE").qfLabel(Theme.accent)
            Text(r.nextEdgeTopic).qf(26, .bold, relativeTo: .title2).foregroundStyle(Theme.text)
            Text(note).qf(15, .regular, relativeTo: .subheadline).foregroundStyle(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qfCard(padding: 18, radius: 22)
        .accessibilityElement(children: .combine)
    }
}
