import SwiftUI

/// QUANTSCAN — ten full-screen questions that measure how you think, then reveal your profile.
struct QuantScanFlow: View {
    let onFinish: () -> Void
    let onClose: () -> Void

    @EnvironmentObject private var model: AppModel
    @StateObject private var scan = ScanSession()

    var body: some View {
        ZStack {
            ScreenBackground()
            switch scan.phase {
            case .intro:
                intro.transition(.opacity)
            case .question, .feedback:
                questionScreen.transition(.opacity)
            case .done:
                ProfileRevealView(result: scan.result, onContinue: onFinish).transition(.opacity)
            }
        }
        .animation(Motion.smooth, value: scan.phase)
        .onChange(of: scan.phase) {
            if scan.phase == .feedback {
                let delay: Double = scan.card.result?.correct == true ? 0.95 : 1.9
                let questionIndex = scan.index
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    // Ignore the timer if the learner already tapped through to a later question.
                    if scan.index == questionIndex { scan.advance(model) }
                }
            }
        }
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                IconButton(symbol: "chevron.left", label: "Back", action: onClose)
                Spacer()
            }
            Spacer()
            Text("QUANTSCAN").qfLabel(Theme.accent)
            Text("Find out how you think.")
                .qf(44, .bold, relativeTo: .largeTitle)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 14) {
                fact("square.stack.3d.up", "10 questions", "Mental math, probability, expected value, logic, estimation and one market call.")
                fact("timer", "About 90 seconds", "Every answer is timed. Speed is part of the profile.")
                fact("function", "No calculator", "Your result is a QuantFlow training score. It is not a hiring prediction.")
            }
            Spacer()
            PrimaryButton(title: "BEGIN SCAN", symbol: "arrow.right") { scan.begin() }
        }
        .padding(24)
        .qfColumn()
    }

    private func fact(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).qf(18, .semibold).foregroundStyle(Theme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).qf(17, .semibold, relativeTo: .headline).foregroundStyle(Theme.text)
                Text(detail).qf(14, .regular, relativeTo: .subheadline).foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Questions

    private var questionScreen: some View {
        let card = scan.card
        return VStack(spacing: 0) {
            topBar(card)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        Image(systemName: card.question.type.symbol).qf(13, .semibold)
                        Text(card.question.header).qfLabel(Theme.accent)
                    }
                    PromptView(question: card.question)
                    if scan.phase == .feedback {
                        scanFeedback(card)
                    } else if !isNumeric(card.question) {
                        AnswerInput(card: card, onSubmit: { scan.submit($0) })
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isNumeric(card.question) && scan.phase == .question {
                AnswerInput(card: card, onSubmit: { scan.submit($0) })
                    .padding(.horizontal, 22)
                    .padding(.bottom, 16)
            }
        }
        .qfColumn()
        .id(card.id)
    }

    private func isNumeric(_ q: QuantQuestion) -> Bool {
        if case .numeric = q.input { return true }
        return false
    }

    private func topBar(_ card: CardState) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                IconButton(symbol: "xmark", label: "Quit scan", action: onClose)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("QUANTSCAN").qfLabel(Theme.text)
                        Spacer()
                        Text("\(scan.index + 1) / \(scan.total)")
                            .qf(13, .semibold, design: .monospaced, relativeTo: .footnote)
                            .foregroundStyle(Theme.textDim)
                    }
                    ProgressBar(value: Double(scan.index + (scan.phase == .feedback ? 1 : 0)) / Double(max(scan.total, 1)), height: 5)
                }
                TimerBar(startedAt: card.startedAt, target: card.question.targetSeconds,
                         frozen: card.isAnswered ? card.elapsed : nil)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func scanFeedback(_ card: CardState) -> some View {
        let ok = card.result?.correct ?? false
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .qf(30, .semibold).foregroundStyle(ok ? Theme.accent : Theme.bad)
                Text(ok ? "CORRECT" : "NOT QUITE")
                    .qf(22, .bold, design: .monospaced, relativeTo: .title2)
                    .foregroundStyle(ok ? Theme.accent : Theme.bad)
                Spacer()
                Text(Fmt.seconds(card.elapsed)).qf(15, .semibold, design: .monospaced, relativeTo: .body)
                    .monospacedDigit().foregroundStyle(Theme.textDim)
            }
            if !ok {
                Text("ANSWER  \(card.question.answer)").qf(20, .bold, design: .monospaced, relativeTo: .title3)
                    .foregroundStyle(Theme.text).minimumScaleFactor(0.6).lineLimit(2)
            }
            Button(action: { scan.advance(model) }) {
                Text("TAP TO CONTINUE").qfLabel()
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Continue to the next question")
        }
        .qfCard(padding: 16, radius: 18)
        .accessibilityElement(children: .contain)
    }
}
