import SwiftUI

/// Custom numeric keypad: digits, decimal point, fraction slash, minus, percent. Hardware-keyboard shortcuts included.
struct Keypad: View {
    let enabled: Bool
    let onKey: (String) -> Void
    let onSubmit: () -> Void

    private let rows: [[String]] = [["1", "2", "3", "⌫"], ["4", "5", "6", "−"], ["7", "8", "9", "/"], [".", "0", "%", "↵"]]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<rows.count, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(0..<rows[r].count, id: \.self) { c in
                        key(rows[r][c])
                    }
                }
            }
        }
        .opacity(enabled ? 1.0 : 0.5)
    }

    private func spoken(_ k: String) -> String {
        switch k {
        case "⌫": return "Delete"
        case "−": return "Minus"
        case "/": return "Slash, for fractions"
        case ".": return "Decimal point"
        case "%": return "Percent"
        case "↵": return "Submit answer"
        default: return k
        }
    }

    private func shortcut(_ k: String) -> KeyEquivalent {
        switch k {
        case "⌫": return KeyEquivalent.delete
        case "↵": return KeyEquivalent.return
        case "−": return KeyEquivalent("-")
        default: return KeyEquivalent(Character(k))
        }
    }

    private func press(_ k: String) {
        guard enabled else { return }
        if k == "↵" {
            onSubmit()
        } else {
            Haptics.tap()
            onKey(k)
        }
    }

    private func key(_ k: String) -> some View {
        let isSubmit = k == "↵"
        let isOperator = k == "⌫" || k == "−" || k == "/" || k == "." || k == "%"
        return Button(action: { press(k) }) {
            ZStack {
                if k == "⌫" {
                    Image(systemName: "delete.left").qf(18, .semibold)
                } else if isSubmit {
                    Image(systemName: "return").qf(18, .bold)
                } else {
                    Text(k).qf(24, .medium, design: .rounded, relativeTo: .title2).lineLimit(1).minimumScaleFactor(0.5)
                }
            }
            .foregroundStyle(isSubmit ? Theme.bg : (isOperator ? Theme.textDim : Theme.text))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background { RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isSubmit ? Theme.accent : Theme.surfaceHigh) }
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .keyboardShortcut(shortcut(k), modifiers: [])
        .accessibilityLabel(spoken(k))
    }
}
