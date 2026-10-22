import SwiftUI

// MARK: - Timer

/// "02.8 sec" with a thin progress bar toward the target time. Turns amber (and swaps its icon) once over target.
struct TimerBar: View {
    let startedAt: Date
    let target: Double
    let frozen: Double?

    var body: some View {
        if let f = frozen {
            content(f).accessibilityElement(children: .ignore).accessibilityLabel("Answered in \(Fmt.num(f, maxDecimals: 1)) seconds")
        } else {
            TimelineView(.periodic(from: startedAt, by: 0.1)) { ctx in
                content(ctx.date.timeIntervalSince(startedAt))
            }
            .accessibilityHidden(true)
        }
    }

    private func content(_ elapsed: Double) -> some View {
        let over = elapsed > target
        return HStack(spacing: 8) {
            Image(systemName: over ? "hourglass.bottomhalf.filled" : "timer").qf(13, .semibold)
            Text(Fmt.seconds(elapsed))
                .qf(15, .semibold, design: .monospaced, relativeTo: .body)
                .monospacedDigit()
            ProgressBar(value: elapsed / max(target, 1), height: 4, tint: over ? Theme.warn : Theme.accent)
                .frame(width: 56)
        }
        .foregroundStyle(over ? Theme.warn : Theme.text)
    }
}

// MARK: - Prompt

struct GambleView: View {
    let legs: [GambleLeg]

    private func percent(_ leg: GambleLeg) -> Int { Int((leg.probability * 100).rounded()) }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<legs.count, id: \.self) { i in
                legRow(legs[i])
            }
        }
        .qfCard(padding: 14, radius: 16, fill: Theme.bgRaised)
    }

    private func legRow(_ leg: GambleLeg) -> some View {
        let tint: Color = leg.payoff >= 0 ? Theme.accent : Theme.bad
        return HStack(spacing: 10) {
            Text("\(percent(leg))%")
                .qf(15, .bold, design: .monospaced, relativeTo: .body)
                .foregroundStyle(Theme.text)
                .frame(width: 54, alignment: .leading)
            ProgressBar(value: leg.probability, height: 8, tint: tint)
            Text(Fmt.signedMoney(leg.payoff, decimals: 0))
                .qf(17, .bold, design: .monospaced, relativeTo: .body)
                .foregroundStyle(tint)
                .frame(width: 80, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(percent(leg)) percent chance of \(Spoken.math(Fmt.signedMoney(leg.payoff, decimals: 0)))")
    }
}

/// The question itself. Short expressions ("49 × 51") are set as a giant hero; sentences stack as context + question.
struct PromptView: View {
    let question: QuantQuestion
    var compact = false

    private var blocks: [String] { question.prompt.components(separatedBy: "\n\n") }

    private var isHero: Bool {
        blocks.count == 1 && question.prompt.filter { $0.isLetter }.count <= 3 && question.prompt.count <= 22
    }

    private var gambleLegs: [GambleLeg]? {
        if case .gamble(let legs) = question.visual { return legs }
        return nil
    }

    private var contextBlocks: [String] {
        if gambleLegs != nil { return [] }
        return Array(blocks.dropLast())
    }

    private var questionBlock: String { blocks.last ?? question.prompt }

    private var toleranceHint: String? {
        if case .numeric(_, _, let tol) = question.input, case .relative(let r) = tol {
            return "Estimate · within \(Fmt.num(r * 100, maxDecimals: 1))%"
        }
        if question.isProbability { return "Fraction, decimal or percent" }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            if question.isReadOnly {
                readHero
            } else if isHero {
                hero
            } else {
                paragraphs
            }
            if let hint = toleranceHint, !question.isReadOnly {
                Text(hint).qfLabel()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Spoken.math(question.prompt))
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(question.prompt)
                .qf(compact ? 40 : 62, .semibold, relativeTo: .largeTitle)
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            if !question.prompt.contains("?") {
                Text("?").qf(compact ? 30 : 44, .light, relativeTo: .title).foregroundStyle(Theme.accent)
            }
        }
    }

    private var readHero: some View {
        Text(question.prompt)
            .qf(compact ? 30 : 40, .semibold, design: .monospaced, relativeTo: .title)
            .foregroundStyle(Theme.text)
            .lineLimit(3)
            .minimumScaleFactor(0.4)
    }

    private var paragraphs: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<contextBlocks.count, id: \.self) { i in
                Text(contextBlocks[i])
                    .qf(compact ? 15 : 17, .regular, relativeTo: .body)
                    .foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let legs = gambleLegs { GambleView(legs: legs) }
            Text(questionBlock)
                .qf(compact ? 21 : 26, .semibold, relativeTo: .title2)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Answer inputs

struct ChoiceList: View {
    @ObservedObject var card: CardState
    let options: [String]
    let correct: Int
    let onPick: (Int) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<options.count, id: \.self) { i in
                row(i)
            }
        }
    }

    private func badge(_ i: Int, answered: Bool, picked: Bool) -> some View {
        let isRight = i == correct
        return ZStack {
            if answered && isRight {
                Image(systemName: "checkmark.circle.fill").qf(22, .semibold).foregroundStyle(Theme.accent)
            } else if answered && picked {
                Image(systemName: "xmark.circle.fill").qf(22, .semibold).foregroundStyle(Theme.bad)
            } else {
                Text(String(UnicodeScalar(UInt8(65 + i % 26))))
                    .qf(14, .bold, design: .monospaced, relativeTo: .body)
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 26, height: 26)
                    .background { Circle().stroke(Theme.lineStrong, lineWidth: 1) }
            }
        }
        .frame(width: 28, height: 28)
    }

    private func row(_ i: Int) -> some View {
        let answered = card.isAnswered
        let picked = card.choice == i
        let isRight = i == correct
        let border: Color = answered ? (isRight ? Theme.accent : (picked ? Theme.bad : Theme.line)) : (picked ? Theme.accent : Theme.line)
        return Button(action: {
            guard !answered else { return }
            Haptics.tap()
            card.choice = i
            onPick(i)
        }) {
            HStack(spacing: 12) {
                badge(i, answered: answered, picked: picked)
                Text(options[i])
                    .qf(17, .medium, relativeTo: .body)
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background { RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface) }
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(border, lineWidth: answered && (isRight || picked) ? 2 : 1) }
        }
        .buttonStyle(PressStyle())
        .disabled(answered)
        .accessibilityLabel("Option \(i + 1): \(options[i])")
    }
}

/// Bid / ask controls for market-making cards: shows the edge versus fair value live.
struct QuotePanel: View {
    @ObservedObject var card: CardState
    let spec: QuoteSpec
    let onPost: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            marketStrip
            QuoteStepperRow(title: "BID", value: card.bid, edge: spec.fair - card.bid, disabled: card.isAnswered,
                            minus: { card.nudgeBid(-1) }, plus: { card.nudgeBid(1) })
            QuoteStepperRow(title: "ASK", value: card.ask, edge: card.ask - spec.fair, disabled: card.isAnswered,
                            minus: { card.nudgeAsk(-1) }, plus: { card.nudgeAsk(1) })
            PrimaryButton(title: "POST QUOTE", symbol: "arrow.up.right", enabled: !card.isAnswered && card.bid < card.ask, action: onPost)
        }
    }

    private var marketStrip: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("FAIR VALUE").qfLabel()
                Text(Fmt.price(spec.fair)).qf(26, .bold, design: .monospaced, relativeTo: .title2).foregroundStyle(Theme.text)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("MARKET").qfLabel()
                Text("\(Fmt.price(spec.marketBid)) × \(Fmt.price(spec.marketAsk))")
                    .qf(15, .semibold, design: .monospaced, relativeTo: .body).foregroundStyle(Theme.text)
                if spec.inventory != 0 {
                    Text("INVENTORY \(spec.inventory > 0 ? "+" : Fmt.minus)\(abs(spec.inventory))").qfLabel(Theme.warn)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Formula / trick cards

struct ReadPanel: View {
    @ObservedObject var card: CardState
    let steps: [String]
    let intuition: String
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<steps.count, id: \.self) { i in
                if i < card.revealed {
                    stepRow(i)
                        .transition(AnyTransition.opacity.combined(with: AnyTransition.move(edge: .top)))
                }
            }
            if card.revealed >= steps.count {
                Text(intuition)
                    .qf(15, .regular, relativeTo: .subheadline)
                    .foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            controls
        }
        .animation(Motion.spring, value: card.revealed)
    }

    private func stepRow(_ i: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(i + 1)")
                .qf(12, .bold, design: .monospaced, relativeTo: .caption)
                .foregroundStyle(Theme.bg)
                .frame(width: 22, height: 22)
                .background { Circle().fill(Theme.accent) }
            Text(steps[i])
                .qf(18, .medium, design: .monospaced, relativeTo: .body)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if card.revealed < steps.count {
            SecondaryButton(title: "REVEAL STEP \(card.revealed + 1) OF \(steps.count)", symbol: "chevron.down") {
                card.revealed += 1
            }
        } else if !card.isAnswered {
            PrimaryButton(title: "GOT IT", symbol: "checkmark", action: onDone)
        }
    }
}

// MARK: - Feedback

struct FeedbackPanel: View {
    @ObservedObject var card: CardState
    var showNext = true
    let onNext: () -> Void

    private var q: QuantQuestion { card.question }
    private var correct: Bool { card.result?.correct ?? false }
    private var skipped: Bool { card.result?.skipped ?? false }
    private var ratio: Double { card.elapsed / max(q.targetSeconds, 1) }
    private var xp: Int { card.outcome?.xp ?? 0 }

    private var verdict: String {
        if q.isReadOnly { return "NOTED" }
        return correct ? "CORRECT" : (skipped ? "SKIPPED" : "NOT QUITE")
    }

    private var verdictSymbol: String {
        if q.isReadOnly { return "checkmark.circle" }
        return correct ? "checkmark.circle.fill" : (skipped ? "arrow.uturn.right.circle.fill" : "xmark.circle.fill")
    }

    private var verdictColor: Color {
        if q.isReadOnly || correct { return Theme.accent }
        return skipped ? Theme.warn : Theme.bad
    }

    private var speedCopy: String {
        if skipped { return "" }
        if !correct { return "Target \(Int(q.targetSeconds)) sec." }
        if ratio <= 0.6 { return "Lightning." }
        if ratio <= 1.0 { return "Fast enough." }
        if ratio <= 1.5 { return "A touch slow." }
        return "Too slow. Target \(Int(q.targetSeconds)) sec."
    }

    private var probabilityValue: Double? {
        if q.isProbability { return q.numericValue }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !q.isReadOnly { answerLine }
            if let note = card.result?.note, !correct, !skipped {
                Text(note).qfLabel()
            }
            Text(q.explanation)
                .qf(16, .regular, relativeTo: .callout)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            if let tip = q.shortcut { shortcutRow(tip) }
            if let p = probabilityValue {
                ProbabilityField(probability: p, height: 100)
            }
            if showNext {
                PrimaryButton(title: "NEXT", symbol: "arrow.up", action: onNext)
                    .accessibilityHint("Shows the next question. You can also swipe up.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: verdictSymbol).qf(20, .semibold).foregroundStyle(verdictColor)
            Text(verdict).qf(17, .bold, design: .monospaced, relativeTo: .headline).foregroundStyle(verdictColor)
            if !q.isReadOnly {
                Text(Fmt.seconds(card.elapsed)).qf(14, .medium, design: .monospaced, relativeTo: .subheadline)
                    .monospacedDigit().foregroundStyle(Theme.textDim)
                Text(speedCopy).qf(14, .medium, relativeTo: .subheadline).foregroundStyle(Theme.textDim).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .overlay(alignment: .trailing) {
            if xp > 0 { XPBurst(amount: xp) }
        }
        .accessibilityElement(children: .combine)
    }

    private var answerLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if correct {
                Image(systemName: "checkmark").qf(24, .bold).foregroundStyle(Theme.accent)
            } else {
                Text("ANSWER").qfLabel()
            }
            Text(q.answer)
                .qf(32, .bold, relativeTo: .title)
                .monospacedDigit()
                .foregroundStyle(correct ? Theme.accent : Theme.text)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
        }
        .accessibilityElement(children: .combine)
    }

    private func shortcutRow(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb").qf(14, .semibold).foregroundStyle(Theme.warn)
            VStack(alignment: .leading, spacing: 2) {
                Text("SHORTCUT").qfLabel(Theme.warn)
                Text(tip).qf(15, .medium, design: .monospaced, relativeTo: .subheadline).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
