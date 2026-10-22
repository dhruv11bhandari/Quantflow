import SwiftUI

/// The typed answer, shown large above the keypad.
struct AnswerReadout: View {
    @ObservedObject var card: CardState

    var body: some View {
        HStack {
            Text(card.input.isEmpty ? "ANSWER" : card.input)
                .qf(34, .semibold, design: .monospaced, relativeTo: .title)
                .foregroundStyle(card.input.isEmpty ? Theme.textDim.opacity(0.45) : Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(card.input.isEmpty ? Theme.line : Theme.accent).frame(height: 1.5) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your answer")
        .accessibilityValue(card.input.isEmpty ? "empty" : Spoken.math(card.input))
    }
}

/// One entry point for every answer style: numeric keypad, multiple choice, or bid / ask quote.
struct AnswerInput: View {
    @ObservedObject var card: CardState
    let onSubmit: (UserAnswer) -> Void

    var body: some View {
        switch card.question.input {
        case .numeric:
            VStack(spacing: 10) {
                AnswerReadout(card: card)
                Keypad(enabled: !card.isAnswered, onKey: { card.typeKey($0) }, onSubmit: submitText)
            }
        case .choice(let options, let correct):
            ChoiceList(card: card, options: options, correct: correct, onPick: { onSubmit(.choice($0)) })
        case .quote(let spec):
            QuotePanel(card: card, spec: spec, onPost: { onSubmit(.quote(bid: card.bid, ask: card.ask)) })
        case .read:
            EmptyView()
        }
    }

    private func submitText() {
        guard !card.input.isEmpty else {
            Haptics.warning()
            return
        }
        onSubmit(.text(card.input))
    }
}
