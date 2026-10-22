import SwiftUI

struct BannerView: View {
    let banner: Banner

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: banner.symbol).qf(20, .semibold).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title).qfLabel(Theme.accent)
                Text(banner.subtitle).qf(15, .semibold, relativeTo: .subheadline).foregroundStyle(Theme.text)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surfaceHigh) }
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.accent.opacity(0.5), lineWidth: 1) }
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}
