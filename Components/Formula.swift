import SwiftUI

/// A formula in large monospaced type. Fractions are drawn as a stacked numerator / bar / denominator.
struct FormulaView: View {
    let lead: String
    let top: String
    let bottom: String?
    var size: CGFloat = 32

    private var spoken: String {
        let body = bottom == nil ? top : "\(top) divided by \(bottom ?? "")"
        return Spoken.math("\(lead) \(body)")
    }

    var body: some View {
        Group {
            if let b = bottom {
                HStack(spacing: 12) {
                    Text(lead)
                        .qf(size * 0.8, .medium, design: .monospaced, relativeTo: .title2)
                        .foregroundStyle(Theme.textDim)
                    VStack(spacing: 6) {
                        Text(top).qf(size * 0.8, .semibold, design: .monospaced, relativeTo: .title2).foregroundStyle(Theme.text)
                        Rectangle().fill(Theme.accent).frame(height: 2)
                        Text(b).qf(size * 0.8, .semibold, design: .monospaced, relativeTo: .title2).foregroundStyle(Theme.text)
                    }
                    .fixedSize()
                }
            } else {
                VStack(spacing: 8) {
                    if !lead.isEmpty {
                        Text(lead).qf(size * 0.62, .medium, design: .monospaced, relativeTo: .title3).foregroundStyle(Theme.textDim)
                    }
                    Text(top)
                        .qf(size, .semibold, design: .monospaced, relativeTo: .title)
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(3)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}
