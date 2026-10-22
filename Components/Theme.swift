import SwiftUI

/// QuantFlow's visual language: near-black, graphite surfaces, off-white text, one electric blue-green accent.
enum Theme {
    static let bg = Color(red: 0.027, green: 0.031, blue: 0.039)
    static let bgRaised = Color(red: 0.047, green: 0.053, blue: 0.063)
    static let surface = Color(red: 0.075, green: 0.083, blue: 0.095)
    static let surfaceHigh = Color(red: 0.115, green: 0.125, blue: 0.141)
    static let line = Color.white.opacity(0.08)
    static let lineStrong = Color.white.opacity(0.18)
    static let text = Color(red: 0.93, green: 0.94, blue: 0.95)
    static let textDim = Color(red: 0.63, green: 0.66, blue: 0.70)
    static let accent = Color(red: 0.18, green: 0.95, blue: 0.78)
    static let blue = Color(red: 0.30, green: 0.62, blue: 1.0)
    static let bad = Color(red: 1.0, green: 0.38, blue: 0.42)
    static let warn = Color(red: 1.0, green: 0.78, blue: 0.32)
}

/// Animation presets. Everything collapses to "no animation" when the system's Reduce Motion is on.
enum Motion {
    static var reduced: Bool { Platform.reduceMotion }
    static var spring: Animation? { reduced ? nil : Animation.spring(response: 0.42, dampingFraction: 0.82) }
    static var quick: Animation? { reduced ? nil : Animation.easeOut(duration: 0.18) }
    static var smooth: Animation? { reduced ? nil : Animation.easeInOut(duration: 0.35) }
    static var slow: Animation? { reduced ? nil : Animation.easeOut(duration: 1.1) }
}

/// A system font that scales with Dynamic Type relative to a text style.
struct QFFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(Font.system(size: size, weight: weight, design: design))
    }
}

extension View {
    func qf(_ size: CGFloat, _ weight: Font.Weight = .regular, design: Font.Design = .default,
            relativeTo: Font.TextStyle = .body) -> some View {
        modifier(QFFont(size: size, weight: weight, design: design, relativeTo: relativeTo))
    }

    /// Small monospaced all-caps label, used for section titles and metadata.
    func qfLabel(_ color: Color = Theme.textDim) -> some View {
        self.qf(11, .semibold, design: .monospaced, relativeTo: .caption)
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    /// Graphite card with a hairline border.
    func qfCard(padding: CGFloat = 16, radius: CGFloat = 22, fill: Color = Theme.surface) -> some View {
        self.padding(padding)
            .background { RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill) }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.line, lineWidth: 1)
            }
    }

    /// Keeps content in a readable column on iPad / landscape.
    func qfColumn(_ width: CGFloat = 640) -> some View {
        self.frame(maxWidth: width).frame(maxWidth: .infinity)
    }
}

/// Subtle press feedback for every tappable surface.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

/// Full-bleed screen background: near-black with a faint accent bloom.
struct ScreenBackground: View {
    var glow: Double = 0.10

    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.accent.opacity(glow), Color.clear], center: .top, startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

struct SectionLabel: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title).qfLabel()
            Spacer()
            if let t = trailing { Text(t).qfLabel(Theme.accent) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A big number with a small caption underneath.
struct StatTile: View {
    let value: String
    let caption: String
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let s = symbol { Image(systemName: s).qf(13, .semibold).foregroundStyle(Theme.accent) }
                Text(value).qf(26, .bold, design: .rounded, relativeTo: .title2).foregroundStyle(Theme.text)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            Text(caption).qfLabel()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qfCard(padding: 14, radius: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(caption): \(value)")
    }
}
