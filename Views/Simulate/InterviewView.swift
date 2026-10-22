import SwiftUI
import Combine

/// MOCK QUANT INTERVIEW — ten questions, two minutes, no calculator, then a report.
struct InterviewView: View {
    let onClose: () -> Void
    let onRestart: () -> Void
    @EnvironmentObject private var model: AppModel
    @StateObject private var session = InterviewSession()
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let seed: UInt64

    init(seed: UInt64, onClose: @escaping () -> Void, onRestart: @escaping () -> Void) {
        self.seed = seed
        self.onClose = onClose
        self.onRestart = onRestart
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            switch session.phase {
            case .intro: intro.transition(.opacity)
            case .running: running.transition(.opacity)
            case .report: report.transition(.opacity)
            }
        }
        .animation(Motion.smooth, value: session.phase)
        .onReceive(timer) { _ in session.tick(model) }
    }

    // MARK: Intro

    private func pill(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).qf(12, .semibold).foregroundStyle(Theme.accent)
            Text(text).qfLabel(Theme.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background { Capsule().fill(Theme.surface) }
        .overlay { Capsule().stroke(Theme.line, lineWidth: 1) }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { IconButton(symbol: "xmark", label: "Close interview", action: onClose); Spacer() }
            Spacer()
            Text("MOCK QUANT INTERVIEW").qfLabel(Theme.accent)
            Text("Think fast.\nStay accurate.").qf(42, .bold, relativeTo: .largeTitle).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                pill("square.stack.3d.up", "10 QUESTIONS")
                pill("timer", "2 MINUTES")
                pill("function", "NO CALCULATOR")
            }
            Text("Mental math, probability, expected value, logic and estimation. Unanswered questions count as wrong. You get a report at the end.")
                .qf(15, .regular, relativeTo: .subheadline).foregroundStyle(Theme.textDim).fixedSize(horizontal: false, vertical: true)
            Spacer()
            PrimaryButton(title: "START THE CLOCK", symbol: "arrow.right") { session.begin(seed: seed) }
        }
        .padding(24)
        .qfColumn()
    }

    // MARK: Running

    private var clock: some View {
        let low = session.remaining < 20
        return HStack(spacing: 8) {
            Image(systemName: low ? "exclamationmark.triangle.fill" : "timer").qf(16, .semibold)
            Text(Fmt.clock(session.remaining))
                .qf(30, .bold, design: .monospaced, relativeTo: .title)
                .monospacedDigit()
        }
        .foregroundStyle(low ? Theme.warn : Theme.text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time remaining")
        .accessibilityValue("\(Int(session.remaining.rounded(.up))) seconds")
    }

    @ViewBuilder
    private var running: some View {
        if let card = session.card {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    IconButton(symbol: "xmark", label: "Quit interview", action: onClose)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("QUESTION \(session.index + 1) / \(session.questions.count)").qfLabel(Theme.text)
                            Spacer()
                        }
                        ProgressBar(value: Double(session.index) / Double(max(session.questions.count, 1)), height: 5)
                    }
                    clock
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 8) {
                            Image(systemName: card.question.type.symbol).qf(13, .semibold)
                            Text(card.question.header).qfLabel(Theme.accent)
                        }
                        PromptView(question: card.question)
                        if !isNumeric(card.question) {
                            AnswerInput(card: card, onSubmit: { session.submit($0, model: model) })
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if isNumeric(card.question) {
                    AnswerInput(card: card, onSubmit: { session.submit($0, model: model) })
                        .padding(.horizontal, 22)
                        .padding(.bottom, 16)
                }
            }
            .qfColumn()
            .id(card.id)
        }
    }

    private func isNumeric(_ q: QuantQuestion) -> Bool {
        if case .numeric = q.input { return true }
        return false
    }

    // MARK: Report

    private func skillOrder() -> [SkillKey] { [.mentalMath, .probability, .logic, .expectedValue, .estimation] }

    @ViewBuilder
    private var report: some View {
        if let r = session.report {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack { IconButton(symbol: "xmark", label: "Close report", action: onClose); Spacer() }
                    Text("INTERVIEW REPORT").qfLabel(Theme.accent)
                    HStack(spacing: 12) {
                        StatTile(value: Fmt.percent(r.accuracy), caption: "ACCURACY", symbol: "checkmark")
                        StatTile(value: Fmt.percent(r.speed), caption: "SPEED", symbol: "bolt.fill")
                    }
                    Text("\(r.correct) of \(r.total) correct · \(Fmt.num(r.secondsUsed, maxDecimals: 0)) of 120 seconds used")
                        .qf(14, .regular, relativeTo: .subheadline).foregroundStyle(Theme.textDim)
                    VStack(spacing: 14) {
                        ForEach(0..<skillOrder().count, id: \.self) { i in
                            let key = skillOrder()[i]
                            if let v = r.bySkill[key.rawValue] {
                                SkillBarRow(name: key.title, value: v * 100, tint: v >= 0.7 ? Theme.accent : Theme.warn)
                            }
                        }
                    }
                    .qfCard(padding: 18, radius: 22)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR NEXT TRAINING FOCUS").qfLabel(Theme.accent)
                        Text(r.focus.joined(separator: " + ")).qf(26, .bold, relativeTo: .title2).foregroundStyle(Theme.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .qfCard(padding: 18, radius: 22)
                    .accessibilityElement(children: .combine)
                    if let rw = session.reward {
                        Text("+\(rw.xp) XP · Training score, not a hiring prediction.").qfLabel()
                    }
                    PrimaryButton(title: "RETAKE", symbol: "arrow.clockwise", action: onRestart)
                    SecondaryButton(title: "DONE", action: onClose)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
            .qfColumn()
        }
    }
}
