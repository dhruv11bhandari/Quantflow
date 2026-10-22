import SwiftUI

struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack(spacing: 8) {
                Text(title).qf(15, .bold, relativeTo: .headline).tracking(1.0)
                if let s = symbol { Image(systemName: s).qf(14, .bold) }
            }
            .foregroundStyle(enabled ? Theme.bg : Theme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background { RoundedRectangle(cornerRadius: 16, style: .continuous).fill(enabled ? Theme.accent : Theme.surfaceHigh) }
            .shadow(color: Theme.accent.opacity(enabled ? 0.32 : 0.0), radius: 14, x: 0, y: 4)
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}

struct SecondaryButton: View {
    let title: String
    var symbol: String? = nil
    var tint: Color = Theme.text
    let action: () -> Void

    var body: some View {
        Button(action: { Haptics.select(); action() }) {
            HStack(spacing: 8) {
                if let s = symbol { Image(systemName: s).qf(14, .semibold) }
                Text(title).qf(14, .semibold, relativeTo: .subheadline).tracking(0.6)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background { RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface) }
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.lineStrong, lineWidth: 1) }
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(title)
    }
}

/// 44-pt circular icon button (close, back, info).
struct IconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: { Haptics.select(); action() }) {
            Image(systemName: symbol)
                .qf(15, .semibold)
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .background { Circle().fill(Theme.surface) }
                .overlay { Circle().stroke(Theme.line, lineWidth: 1) }
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

/// Segmented control built from buttons (works for any Hashable option).
struct SegmentedChoice<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let title: (T) -> String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<options.count, id: \.self) { i in
                segment(options[i])
            }
        }
        .padding(4)
        .background { RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface) }
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1) }
    }

    private func segment(_ option: T) -> some View {
        let selected = option == selection
        let traits: AccessibilityTraits = selected ? [.isButton, .isSelected] : [.isButton]
        return Button(action: {
            Haptics.select()
            withAnimation(Motion.quick) { selection = option }
        }) {
            Text(title(option))
                .qf(13, .semibold, design: .monospaced, relativeTo: .footnote)
                .foregroundStyle(selected ? Theme.bg : Theme.textDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(selected ? Theme.accent : Color.clear) }
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(title(option))
        .accessibilityAddTraits(traits)
    }
}
