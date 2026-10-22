import SwiftUI

/// FORMULA ↓ INTUITION ↓ EXAMPLE ↓ CHALLENGE
struct ConceptView: View {
    let concept: Concept
    let onClose: () -> Void
    @State private var card: CardState
    @State private var started = false

    init(concept: Concept, onClose: @escaping () -> Void) {
        self.concept = concept
        self.onClose = onClose
        _card = State(initialValue: CardState(question: concept.challenge))
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    IconButton(symbol: "xmark", label: "Close", action: onClose)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(concept.category.title).qfLabel(Theme.accent)
                        Text(concept.title).qf(18, .bold, relativeTo: .headline).foregroundStyle(Theme.text).lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        stage("FORMULA") {
                            FormulaView(lead: concept.formulaLead, top: concept.formulaTop, bottom: concept.formulaBottom, size: 30)
                                .padding(.vertical, 10)
                        }
                        arrow
                        stage("INTUITION") {
                            Text(concept.intuition).qf(18, .regular, relativeTo: .body).foregroundStyle(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        arrow
                        stage("EXAMPLE") {
                            Text(concept.example).qf(17, .medium, design: .monospaced, relativeTo: .body).foregroundStyle(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        arrow
                        stage("CHALLENGE") {
                            ChallengeSection(concept: concept, card: card, started: $started, retry: {
                                card = CardState(question: concept.challenge)
                            })
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
            .qfColumn()
        }
    }

    private var arrow: some View {
        Image(systemName: "arrow.down").qf(14, .semibold).foregroundStyle(Theme.textDim)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private func stage<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).qfLabel(Theme.accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qfCard(padding: 16, radius: 22)
    }
}

struct ChallengeSection: View {
    let concept: Concept
    @ObservedObject var card: CardState
    @Binding var started: Bool
    let retry: () -> Void
    @EnvironmentObject private var model: AppModel

    private var learned: Bool { model.save.learned.contains("concept." + concept.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !started {
                Text("Test the idea on one question.").qf(16, .regular, relativeTo: .body).foregroundStyle(Theme.textDim)
                PrimaryButton(title: "TRY IT", symbol: "play.fill") {
                    withAnimation(Motion.spring) { started = true }
                }
            } else {
                PromptView(question: concept.challenge, compact: true)
                if card.isAnswered {
                    FeedbackPanel(card: card, showNext: false, onNext: {})
                    if card.result?.correct == true {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.accent)
                            Text(learned ? "CONCEPT LEARNED" : "KEEP GOING").qfLabel(Theme.accent)
                        }
                        .accessibilityElement(children: .combine)
                    } else {
                        SecondaryButton(title: "TRY AGAIN", symbol: "arrow.clockwise", action: retry)
                    }
                } else {
                    TimerBar(startedAt: card.startedAt, target: concept.challenge.targetSeconds, frozen: nil)
                    AnswerInput(card: card, onSubmit: submit)
                }
            }
        }
    }

    private func submit(_ answer: UserAnswer) {
        guard !card.isAnswered else { return }
        let elapsed = Date().timeIntervalSince(card.startedAt)
        let result = AnswerEvaluator.evaluate(concept.challenge, answer)
        var outcome = model.record(concept.challenge, result: result, seconds: elapsed, source: .learn)
        if result.correct { outcome.xp += model.markLearned(concept.id) }
        card.elapsed = elapsed
        card.result = result
        card.outcome = outcome
        card.phase = .answered
        if result.correct { Haptics.success() } else { Haptics.error() }
    }
}
