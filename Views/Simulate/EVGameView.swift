import SwiftUI
import Combine
import Charts

struct ConvergePoint: Identifiable {
    let id: Int
    let a: Double
    let b: Double
}

/// EV GAME — pick the better gamble, then watch repeated plays converge to the expected value.
struct EVGameView: View {
    let onClose: () -> Void
    let onRestart: () -> Void
    @EnvironmentObject private var model: AppModel
    @StateObject private var session: EVGameSession
    @State private var timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    init(seed: UInt64, onClose: @escaping () -> Void, onRestart: @escaping () -> Void) {
        self.onClose = onClose
        self.onRestart = onRestart
        _session = StateObject(wrappedValue: EVGameSession(seed: seed))
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 0) {
                topBar
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        switch session.phase {
                        case .intro: intro
                        case .choosing, .reveal: play
                        case .summary: summary
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .qfColumn()
        }
        .onReceive(timer) { _ in session.tick() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            IconButton(symbol: "xmark", label: "Close EV Game", action: onClose)
            VStack(alignment: .leading, spacing: 2) {
                Text("EV GAME").qfLabel(Theme.text)
                if session.phase == .choosing || session.phase == .reveal {
                    Text("ROUND \(session.index + 1) OF \(session.rounds.count)").qfLabel(Theme.textDim)
                }
            }
            Spacer()
            if session.phase != .intro {
                Text("\(session.correctCount) ✓").qf(18, .bold, design: .monospaced, relativeTo: .headline).foregroundStyle(Theme.accent)
                    .accessibilityLabel("\(session.correctCount) correct")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SIX ROUNDS").qfLabel(Theme.accent)
            Text("Which gamble\nhas the higher EV?").qf(38, .bold, relativeTo: .largeTitle).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("Expected value is what a gamble averages over many repetitions. Pick the better one, then watch 240 simulated plays settle on the answer.")
                .qf(16, .regular, relativeTo: .body).foregroundStyle(Theme.textDim).fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: "START", symbol: "arrow.right") { session.begin() }
        }
    }

    // MARK: Play

    private func termText(_ leg: GambleLeg) -> String {
        let p = Fmt.num(leg.probability, maxDecimals: 2)
        let x = leg.payoff < 0 ? "(\(Fmt.num(leg.payoff)))" : Fmt.num(leg.payoff)
        return "\(p) × \(x)"
    }

    private func calcText(_ g: Gamble) -> String {
        let terms = g.legs.map { termText($0) }.joined(separator: " + ")
        return "\(terms) = \(Fmt.num(g.ev, maxDecimals: 2))"
    }

    private func gambleCard(_ title: String, _ g: Gamble, choice: GameChoice) -> some View {
        let revealed = session.phase == .reveal
        let isBetter = session.round.better == choice
        let picked = session.picked == choice
        let border: Color = revealed ? (isBetter ? Theme.accent : Theme.line) : Theme.line
        return Button(action: { session.pick(choice) }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).qfLabel(Theme.accent)
                    Spacer()
                    if revealed && isBetter {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill").qf(13, .bold)
                            Text("HIGHER EV").qfLabel(Theme.accent)
                        }
                    }
                    if revealed && picked {
                        Text("YOUR PICK").qfLabel(Theme.text)
                    }
                }
                GambleView(legs: g.legs)
                if revealed {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EXPECTED VALUE").qfLabel()
                        Text(calcText(g)).qf(15, .semibold, design: .monospaced, relativeTo: .subheadline).foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(AnyTransition.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .qfCard(padding: 16, radius: 22)
            .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(border, lineWidth: revealed && isBetter ? 2 : 1) }
        }
        .buttonStyle(PressStyle())
        .disabled(revealed)
        .accessibilityElement(children: .combine)
        .accessibilityHint(revealed ? "" : "Choose \(title) as the higher expected value.")
    }

    private var chartPoints: [ConvergePoint] {
        let n = min(session.plays, session.seriesA.count, session.seriesB.count)
        if n < 2 { return [] }
        var out: [ConvergePoint] = []
        var i = 0
        while i < n {
            out.append(ConvergePoint(id: i + 1, a: session.seriesA[i], b: session.seriesB[i]))
            i += 3
        }
        return out
    }

    private var convergenceChart: some View {
        let evA = session.round.a.ev
        let evB = session.round.b.ev
        let lo = min(evA, evB) - 5
        let hi = max(evA, evB) + 5
        return VStack(alignment: .leading, spacing: 8) {
            Text("AVERAGE OVER \(session.plays) PLAYS").qfLabel()
            Chart(chartPoints) { p in
                LineMark(x: .value("Play", p.id), y: .value("Average", p.a), series: .value("Game", "A"))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                LineMark(x: .value("Play", p.id), y: .value("Average", p.b), series: .value("Game", "B"))
                    .foregroundStyle(Theme.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                if p.id == 1 {
                    RuleMark(y: .value("EV A", evA))
                        .foregroundStyle(Theme.accent.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    RuleMark(y: .value("EV B", evB))
                        .foregroundStyle(Theme.blue.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartYScale(domain: lo...hi)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Theme.line)
                    AxisValueLabel().foregroundStyle(Theme.textDim)
                }
            }
            .frame(height: 170)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Running average payoff of each game, converging toward its expected value")
            .accessibilityValue("Game A expected value \(Fmt.num(evA, maxDecimals: 2)). Game B expected value \(Fmt.num(evB, maxDecimals: 2)).")
            HStack(spacing: 16) {
                legendItem("GAME A · SOLID", Theme.accent)
                legendItem("GAME B · DASHED", Theme.blue)
            }
        }
        .qfCard(padding: 16, radius: 22)
    }

    private func legendItem(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(color).frame(width: 16, height: 3)
            Text(text).qfLabel()
        }
    }

    @ViewBuilder
    private var play: some View {
        VStack(alignment: .leading, spacing: 14) {
            if session.phase == .choosing {
                Text("Which has the higher expected value?").qf(24, .bold, relativeTo: .title2).foregroundStyle(Theme.text)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: session.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .qf(24, .semibold).foregroundStyle(session.wasCorrect ? Theme.accent : Theme.bad)
                    Text(session.wasCorrect ? "CORRECT" : "NOT QUITE")
                        .qf(22, .bold, design: .monospaced, relativeTo: .title2)
                        .foregroundStyle(session.wasCorrect ? Theme.accent : Theme.bad)
                }
                .accessibilityElement(children: .combine)
            }
            gambleCard("GAME A", session.round.a, choice: .a)
            gambleCard("GAME B", session.round.b, choice: .b)
            if session.phase == .reveal {
                convergenceChart.transition(AnyTransition.opacity)
                PrimaryButton(title: session.index + 1 >= session.rounds.count ? "SEE RESULT" : "NEXT ROUND", symbol: "arrow.right") {
                    session.next(model)
                }
            }
        }
        .animation(Motion.smooth, value: session.phase)
    }

    // MARK: Summary

    @ViewBuilder
    private var summary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("EV INSTINCT").qfLabel(Theme.accent)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(session.correctCount) / \(session.rounds.count)").qf(64, .bold, design: .rounded, relativeTo: .largeTitle).foregroundStyle(Theme.text)
                Text("CORRECT").qfLabel()
            }
            Text(session.correctCount >= 5 ? "Sharp. You price gambles by what they average, not by how they feel." :
                    "Weigh each payoff by its probability, then add. The loud payoff isn't always the better bet.")
                .qf(16, .regular, relativeTo: .body).foregroundStyle(Theme.textDim).fixedSize(horizontal: false, vertical: true)
            if let rw = session.reward {
                HStack {
                    Text("EXPECTED VALUE SKILL").qfLabel()
                    Spacer()
                    Text("\(Int(model.skills.expectedValue.rounded()))").qf(18, .bold, design: .monospaced, relativeTo: .headline).foregroundStyle(Theme.text)
                    Text("+\(rw.xp) XP").qfLabel(Theme.accent)
                }
                .accessibilityElement(children: .combine)
            }
            PrimaryButton(title: "PLAY AGAIN", symbol: "arrow.clockwise", action: onRestart)
            SecondaryButton(title: "DONE", action: onClose)
        }
    }
}
