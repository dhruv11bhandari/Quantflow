import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case train, simulate, learn, progress, profile

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    var symbol: String {
        switch self {
        case .train: return "bolt.fill"
        case .simulate: return "chart.line.uptrend.xyaxis"
        case .learn: return "function"
        case .progress: return "chart.bar.fill"
        case .profile: return "person.fill"
        }
    }
}

struct MainView: View {
    @State private var tab: MainTab

    init(initialTab: MainTab) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            content
        }
        .safeAreaInset(edge: .bottom) { TabBar(selection: $tab) }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .train: TrainScreen(goTo: { tab = $0 })
        case .simulate: SimulateScreen()
        case .learn: LearnScreen()
        case .progress: ProgressScreen(goTo: { tab = $0 })
        case .profile: ProfileScreen()
        }
    }
}

struct TabBar: View {
    @Binding var selection: MainTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                item(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
        }
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func item(_ tab: MainTab) -> some View {
        let selected = tab == selection
        let traits: AccessibilityTraits = selected ? [.isButton, .isSelected] : [.isButton]
        return Button(action: {
            guard tab != selection else { return }
            Haptics.select()
            withAnimation(Motion.spring) { selection = tab }
        }) {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol).qf(18, .semibold)
                Text(tab.title)
                    .qf(9.5, .semibold, design: .monospaced, relativeTo: .caption2)
                    .tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(selected ? Theme.accent : Theme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if selected {
                    Capsule().fill(Theme.accent.opacity(0.12)).matchedGeometryEffect(id: "tab", in: ns)
                }
            }
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(tab.rawValue.capitalized)
        .accessibilityAddTraits(traits)
    }
}
