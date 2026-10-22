import SwiftUI

/// "BID  −  102.10  +   EDGE +0.30" — shared by the feed's market-making cards and the Market Maker simulator.
struct QuoteStepperRow: View {
    let title: String
    let value: Double
    /// Distance from fair value on the side being quoted (positive = you earn edge).
    let edge: Double
    var disabled = false
    let minus: () -> Void
    let plus: () -> Void

    private func stepButton(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.select(); action() }) {
            Image(systemName: symbol)
                .qf(16, .bold)
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .background { Circle().fill(Theme.surfaceHigh) }
        }
        .buttonStyle(PressStyle())
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    var body: some View {
        let negative = edge < -0.0001
        return HStack(spacing: 8) {
            Text(title).qfLabel(Theme.text).frame(width: 38, alignment: .leading)
            stepButton("minus", "Lower \(title.lowercased())", minus)
            Text(Fmt.price(value))
                .qf(24, .bold, design: .monospaced, relativeTo: .title2)
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
            stepButton("plus", "Raise \(title.lowercased())", plus)
            HStack(spacing: 3) {
                if negative { Image(systemName: "exclamationmark.triangle.fill").qf(11, .bold) }
                Text("EDGE \(Fmt.signed(edge, decimals: 2))")
                    .qf(11, .semibold, design: .monospaced, relativeTo: .caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(negative ? Theme.bad : Theme.textDim)
            .frame(width: 84, alignment: .trailing)
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(Fmt.price(value)), edge \(Fmt.signed(edge, decimals: 2)) against fair value")
    }
}

/// Three small bars + word: volatility readable without colour.
struct VolatilityMeter: View {
    let volatility: Volatility

    private var level: Int {
        switch volatility {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i < level ? Theme.warn : Theme.surfaceHigh).frame(width: 12, height: 6)
                }
            }
            Text("VOL \(volatility.title)").qfLabel(Theme.text)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Volatility \(volatility.rawValue)")
    }
}
