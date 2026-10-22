import SwiftUI

/// Horizontal shake used when an answer is wrong.
struct ShakeEffect: ViewModifier, Animatable {
    var amount: CGFloat

    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func body(content: Content) -> some View {
        let wave = sin(Double(amount) * Double.pi * 6)
        let decay = Double(1 - amount)
        return content.offset(x: CGFloat(9 * wave * decay))
    }
}

/// One full-screen card in the TRAIN feed.
struct FeedCardView: View {
    @ObservedObject var card: CardState
    @State private var shake: CGFloat = 0
    @State private var squeeze = false
    let onSubmit: (UserAnswer) -> Void
    let onAcknowledge: () -> Void
    let onSkip: () -> Void
    let onNext: () -> Void

    private var q: QuantQuestion { card.question }

    private var isNumeric: Bool {
        if case .numeric = q.input { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    PromptView(question: q)
                    middle
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isNumeric && !card.isAnswered {
                AnswerInput(card: card, onSubmit: onSubmit)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)
            }
        }
        .scaleEffect(squeeze ? 0.985 : 1.0)
        .modifier(ShakeEffect(amount: shake))
        .onChange(of: card.phase) { react() }
    }

    /// Correct: the card compresses slightly. Wrong: a short shake. Both are skipped under Reduce Motion.
    private func react() {
        guard card.isAnswered, !q.isReadOnly, !Motion.reduced else { return }
        if card.result?.correct == true {
            withAnimation(Animation.easeOut(duration: 0.12)) { squeeze = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(Animation.spring(response: 0.35, dampingFraction: 0.6)) { squeeze = false }
            }
        } else if card.result?.skipped != true {
            withAnimation(Animation.linear(duration: 0.42)) { shake = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) { shake = 0 }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: q.type.symbol).qf(13, .semibold)
                Text(q.header).qfLabel(Theme.accent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background { Capsule().fill(Theme.accent.opacity(0.10)) }
            .accessibilityElement(children: .combine)
            if card.isReview {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath").qf(11, .semibold)
                    Text("REVIEW").qfLabel(Theme.warn)
                }
                .foregroundStyle(Theme.warn)
                .accessibilityElement(children: .combine)
                .accessibilityHint("You missed a question like this earlier.")
            }
            if !q.isReadOnly { difficultyDots }
            Spacer(minLength: 0)
            if !q.isReadOnly {
                TimerBar(startedAt: card.startedAt, target: q.targetSeconds, frozen: card.isAnswered ? card.elapsed : nil)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private var difficultyDots: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Circle().fill(i < q.difficulty ? Theme.accent : Theme.surfaceHigh).frame(width: 5, height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Difficulty \(q.difficulty) of 5")
    }

    // MARK: Body by state

    @ViewBuilder
    private var middle: some View {
        if card.isAnswered {
            FeedbackPanel(card: card, onNext: onNext)
                .transition(AnyTransition.opacity)
        } else if case .read(let steps) = q.input {
            ReadPanel(card: card, steps: steps, intuition: q.explanation, onDone: onAcknowledge)
        } else if !isNumeric {
            VStack(alignment: .leading, spacing: 14) {
                AnswerInput(card: card, onSubmit: onSubmit)
                skipButton
            }
        } else {
            skipButton
        }
    }

    private var skipButton: some View {
        Button(action: { Haptics.select(); onSkip() }) {
            HStack(spacing: 6) {
                Text("SKIP").qfLabel()
                Image(systemName: "forward.end").qf(11, .semibold).foregroundStyle(Theme.textDim)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Skip this question")
        .accessibilityHint("Counts as a miss and shows the answer.")
    }
}
