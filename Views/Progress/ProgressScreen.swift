import SwiftUI
import Charts

struct TopicRow: Identifiable {
    let id: String
    let topic: QuantTopic
    let stat: TopicStat
}

/// PROGRESS: the quant-readiness score, skill radar, streak and trend — the "wow" screen of the demo.
struct ProgressScreen: View {
    let goTo: (MainTab) -> Void
    @EnvironmentObject private var model: AppModel
    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            ScreenBackground(glow: 0.12)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    hero
                    radarCard
                    statsRow
                    levelCard
                    trendCard
                    topicCard
                    closing
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .qfColumn()
        }
        .onAppear { withAnimation(Motion.slow) { shown = Double(model.readiness) } }
    }

    private var header: some View {
        HStack {
            Text("PROGRESS").qfLabel(Theme.accent)
            Spacer()
            if model.save.isDemo {
                Text("DEMO DATA").qfLabel(Theme.warn)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background { Capsule().fill(Theme.warn.opacity(0.12)) }
                    .accessibilityLabel("Demo data. This is a sample profile.")
            }
        }
        .padding(.top, 14)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                RingGauge(progress: shown / 100, lineWidth: 16)
                VStack(spacing: 2) {
                    Text("QUANTFLOW").qfLabel()
                    CountUp(value: shown)
                        .qf(92, .bold, design: .rounded, relativeTo: .largeTitle)
                        .foregroundStyle(Theme.text)
                    Text("QUANT READINESS").qfLabel(Theme.accent)
                }
            }
            .frame(width: 250, height: 250)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Quant readiness")
            .accessibilityValue("\(model.readiness) out of 100")
            Text("QuantFlow Training Score · not a hiring prediction")
                .qf(13, .regular, relativeTo: .footnote).foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity)
    }

    private var radarCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SKILL MAP").qfLabel()
            RadarChart(skills: SkillKey.allCases, values: SkillKey.allCases.map { model.skills[$0] })
                .frame(height: 300)
        }
        .qfCard(padding: 16, radius: 24)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: Fmt.grouped(model.save.questionsSolved), caption: "SOLVED")
            StatTile(value: "\(model.streak)", caption: "DAY STREAK", symbol: "flame.fill")
            StatTile(value: Fmt.num(model.save.avgSeconds, maxDecimals: 1) + "s", caption: "AVG RESPONSE")
        }
    }

    private var levelCard: some View {
        let lvl = model.level
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LEVEL").qfLabel()
                Spacer()
                Text("\(Fmt.grouped(model.save.xp)) XP").qf(14, .semibold, design: .monospaced, relativeTo: .subheadline).foregroundStyle(Theme.text)
            }
            Text(lvl.name).qf(26, .bold, design: .monospaced, relativeTo: .title2).foregroundStyle(Theme.text)
            ProgressBar(value: lvl.progress, height: 8)
            if let next = lvl.nextXP {
                Text("\(Fmt.grouped(next - model.save.xp)) XP to \(ScoringEngine.levelTable[min(lvl.index + 1, ScoringEngine.levelTable.count - 1)].name)")
                    .qfLabel()
            } else {
                Text("TOP LEVEL").qfLabel(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qfCard(padding: 16, radius: 22)
        .accessibilityElement(children: .combine)
    }

    // MARK: Trend

    private var trendCard: some View {
        let pts = model.save.scoreHistory
        let values = pts.map { $0.value }
        let lo = Double(max(0, (values.min() ?? 0) - 8))
        let hi = Double(min(100, (values.max() ?? 100) + 8))
        let spoken: String = {
            guard let f = pts.first, let l = pts.last, pts.count > 1 else { return "Not enough history yet." }
            return "Readiness moved from \(f.value) to \(l.value) over \(pts.count) days."
        }()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("READINESS TREND").qfLabel()
                Spacer()
                if let f = pts.first, let l = pts.last, pts.count > 1 {
                    Text("\(f.value) → \(l.value)").qf(13, .semibold, design: .monospaced, relativeTo: .footnote).foregroundStyle(Theme.accent)
                }
            }
            if pts.count > 1 {
                Chart(pts) { point in
                    AreaMark(x: .value("Day", point.date), y: .value("Readiness", point.value))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.35), Color.clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Day", point.date), y: .value("Readiness", point.value))
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: lo...hi)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Theme.line)
                        AxisValueLabel().foregroundStyle(Theme.textDim)
                    }
                }
                .frame(height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Readiness trend chart")
                .accessibilityValue(spoken)
            } else {
                Text("Train again tomorrow to start your trend line.").qf(14, .regular, relativeTo: .subheadline).foregroundStyle(Theme.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qfCard(padding: 16, radius: 22)
    }

    // MARK: Topics

    private var topicRows: [TopicRow] {
        var rows: [TopicRow] = []
        for t in QuantTopic.allCases {
            let s = model.save.topicStat(t)
            if s.attempts >= 5 { rows.append(TopicRow(id: t.rawValue, topic: t, stat: s)) }
        }
        return rows.sorted { $0.stat.accuracy < $1.stat.accuracy }
    }

    private var topicCard: some View {
        let rows = Array(topicRows.prefix(5))
        return VStack(alignment: .leading, spacing: 12) {
            Text("WEAKEST TOPICS").qfLabel()
            if rows.isEmpty {
                Text("Answer a few questions to see accuracy by topic.").qf(14, .regular, relativeTo: .subheadline).foregroundStyle(Theme.textDim)
            } else {
                ForEach(rows) { r in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(r.topic.title).qf(15, .medium, relativeTo: .subheadline).foregroundStyle(Theme.text)
                            Spacer()
                            Text(Fmt.percent(r.stat.accuracy)).qf(14, .bold, design: .monospaced, relativeTo: .subheadline).foregroundStyle(Theme.text)
                            Text("· \(r.stat.attempts)").qfLabel()
                        }
                        ProgressBar(value: r.stat.accuracy, height: 5, tint: r.stat.accuracy < 0.7 ? Theme.warn : Theme.accent)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(r.topic.title): \(Fmt.percent(r.stat.accuracy)) accuracy over \(r.stat.attempts) questions")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qfCard(padding: 16, radius: 22)
    }

    // MARK: Closing line

    private var closing: some View {
        let edge = ScoringEngine.nextEdge(model.skills)
        return VStack(alignment: .leading, spacing: 14) {
            Text("YOUR NEXT EDGE").qfLabel(Theme.accent)
            Text("Your next edge\nis waiting.").qf(38, .bold, relativeTo: .largeTitle).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("Next up: \(edge.focusTopic).").qf(16, .regular, relativeTo: .body).foregroundStyle(Theme.textDim)
            PrimaryButton(title: "KEEP TRAINING", symbol: "bolt.fill") { goTo(.train) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qfCard(padding: 20, radius: 26)
        .overlay { RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.accent.opacity(0.35), lineWidth: 1) }
    }
}
