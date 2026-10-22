import SwiftUI

/// TRAIN: a vertical, full-screen feed that turns scrolling into training.
struct TrainScreen: View {
    let goTo: (MainTab) -> Void

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var train: TrainSession
    @State private var dragY: CGFloat = 0
    @State private var showGoalSheet = false

    var body: some View {
        ZStack {
            ScreenBackground(glow: 0.07)
            VStack(spacing: 0) {
                hud
                feed
            }
            .qfColumn()
            overlays
        }
        .onAppear {
            train.begin(model)
            train.current?.restartClock()
        }
        .sheet(isPresented: $showGoalSheet) { GoalSheet() }
    }

    // MARK: HUD

    private var hud: some View {
        let target = max(model.save.dailyTarget, 1)
        let done = model.save.todayCount
        return VStack(spacing: 10) {
            HStack(alignment: .center) {
                Button(action: { Haptics.select(); showGoalSheet = true }) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("TODAY").qfLabel()
                            Text("\(done) / \(target)")
                                .qf(15, .bold, design: .monospaced, relativeTo: .body)
                                .monospacedDigit()
                                .foregroundStyle(Theme.text)
                            Text("\(model.save.dailyGoalMinutes) MIN").qfLabel(Theme.textDim.opacity(0.8))
                        }
                        SegmentMeter(filled: min(done, target), total: target)
                            .frame(width: 168)
                    }
                }
                .buttonStyle(PressStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Today: \(done) of \(target) questions. Daily goal \(model.save.dailyGoalMinutes) minutes.")
                .accessibilityHint("Opens daily goal settings.")
                Spacer()
                HStack(spacing: 14) {
                    chip("flame.fill", "\(model.streak)", Theme.warn, "Day streak \(model.streak)")
                    chip("bolt.fill", Fmt.grouped(model.save.xp), Theme.accent, "\(model.save.xp) experience points")
                }
            }
            edgeRow
            deskHint
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .animation(Motion.spring, value: showDeskHint)
    }

    private func chip(_ symbol: String, _ value: String, _ tint: Color, _ spoken: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).qf(13, .bold).foregroundStyle(tint)
            Text(value).qf(15, .bold, design: .rounded, relativeTo: .body).monospacedDigit().foregroundStyle(Theme.text)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var edgeRow: some View {
        let edge = ScoringEngine.nextEdge(model.skills)
        return HStack(spacing: 8) {
            Image(systemName: "scope").qf(12, .semibold).foregroundStyle(Theme.accent)
            Text("YOUR NEXT EDGE").qfLabel(Theme.accent)
            Text(edge.focusTopic).qf(13, .medium, relativeTo: .footnote).foregroundStyle(Theme.text).lineLimit(1)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Feed

    private var cardTransition: AnyTransition {
        if Motion.reduced { return AnyTransition.opacity }
        let enter = AnyTransition.move(edge: .bottom).combined(with: AnyTransition.opacity)
        let leave = AnyTransition.move(edge: .top).combined(with: AnyTransition.opacity)
        return AnyTransition.asymmetric(insertion: enter, removal: leave)
    }

    private var feed: some View {
        ZStack {
            if let card = train.current {
                FeedCardView(card: card,
                             onSubmit: { train.submit($0, model: model) },
                             onAcknowledge: { train.acknowledge(model: model) },
                             onSkip: { train.submit(.skipped, model: model) },
                             onNext: advance)
                    .id(card.id)
                    .offset(y: dragY)
                    .transition(cardTransition)
                    .gesture(swipe(card))
                    .accessibilityAction(named: "Next question") { if card.isAnswered { advance() } }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func advance() {
        Haptics.soft()
        withAnimation(Motion.spring) {
            dragY = 0
            train.advance(model)
        }
    }

    private func swipe(_ card: CardState) -> some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                let h = value.translation.height
                if card.isAnswered {
                    dragY = min(0, h)
                } else {
                    dragY = h < 0 ? max(h / 6, -22) : 0
                }
            }
            .onEnded { value in
                let h = value.translation.height
                let fling = value.predictedEndTranslation.height
                if card.isAnswered && (h < -80 || fling < -260) {
                    advance()
                } else {
                    withAnimation(Motion.spring) { dragY = 0 }
                }
            }
    }

    // MARK: Desk hint

    /// After the five opening cards, point first-time learners at the Market Maker (the showpiece).
    private var showDeskHint: Bool {
        train.shownThisRun >= 5 && model.save.marketSessions == 0 && (train.current?.isAnswered ?? false) && !train.showGoalComplete
    }

    @ViewBuilder
    private var deskHint: some View {
        if showDeskHint {
            Button(action: { Haptics.tap(); goTo(.simulate) }) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis").qf(13, .semibold)
                    Text("NEXT: TRY THE MARKET MAKER").qf(11, .bold, design: .monospaced, relativeTo: .caption).tracking(0.8)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right").qf(12, .bold)
                }
                .foregroundStyle(Theme.bg)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background { Capsule().fill(Theme.accent) }
            }
            .buttonStyle(PressStyle())
            .transition(AnyTransition.opacity)
            .accessibilityLabel("Try the Market Maker simulation")
            .accessibilityHint("Opens the Simulate tab.")
        }
    }

    // MARK: Overlays

    @ViewBuilder
    private var overlays: some View {
        if let skill = train.masteredSkill {
            MasteredOverlay(skill: skill)
                .transition(AnyTransition.scale(scale: 0.8).combined(with: AnyTransition.opacity))
        }
        if train.showGoalComplete {
            GoalCompleteOverlay(
                answered: model.save.todayCount,
                accuracy: model.save.accuracy,
                onProgress: { train.showGoalComplete = false; goTo(.progress) },
                onContinue: { withAnimation(Motion.spring) { train.showGoalComplete = false } })
                .transition(AnyTransition.opacity)
        }
    }
}

/// "MASTERED" — shown when a skill crosses the mastery threshold.
struct MasteredOverlay: View {
    let skill: SkillKey
    @State private var pop = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "seal.fill").qf(44, .semibold).foregroundStyle(Theme.accent)
            Text("MASTERED").qf(34, .heavy, design: .monospaced, relativeTo: .largeTitle).tracking(3).foregroundStyle(Theme.text)
            Text(skill.title).qfLabel(Theme.accent)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 26)
        .background { RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.ultraThinMaterial) }
        .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.accent.opacity(0.6), lineWidth: 1.5) }
        .shadow(color: Theme.accent.opacity(0.35), radius: 30, x: 0, y: 0)
        .scaleEffect(pop ? 1.0 : 0.85)
        .onAppear { withAnimation(Motion.spring) { pop = true } }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mastered: \(skill.name)")
    }
}

struct GoalCompleteOverlay: View {
    let answered: Int
    let accuracy: Double
    let onProgress: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "checkmark.seal.fill").qf(34, .semibold).foregroundStyle(Theme.accent)
                Text("DAILY GOAL COMPLETE").qf(24, .bold, design: .monospaced, relativeTo: .title2).foregroundStyle(Theme.text)
                Text("\(answered) questions today · \(Fmt.percent(accuracy)) accuracy · +20 XP")
                    .qf(15, .regular, relativeTo: .subheadline).foregroundStyle(Theme.textDim)
                Text("That's the session. Short, focused reps beat endless scrolling — come back tomorrow to protect your streak.")
                    .qf(15, .regular, relativeTo: .subheadline).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton(title: "SEE MY PROGRESS", symbol: "chart.bar.fill", action: onProgress)
                SecondaryButton(title: "KEEP GOING", action: onContinue)
            }
            .padding(24)
            .background { RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.surface) }
            .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.accent.opacity(0.5), lineWidth: 1) }
            .padding(24)
            .qfColumn(560)
        }
    }
}

struct GoalSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("DAILY GOAL").qfLabel(Theme.accent).padding(.top, 8)
            Text("How long do you want to train today?").qf(22, .bold, relativeTo: .title3).foregroundStyle(Theme.text)
            SegmentedChoice(options: [5, 10, 15], selection: Binding(get: { model.save.dailyGoalMinutes },
                                                                     set: { model.setDailyGoal(minutes: $0) }),
                            title: { "\($0) MIN" })
            Text("That's \(model.save.dailyTarget) questions. QuantFlow is built for short, intentional sessions — it stops pushing you when you hit the goal.")
                .qf(14, .regular, relativeTo: .subheadline).foregroundStyle(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            PrimaryButton(title: "DONE", action: { dismiss() })
        }
        .padding(24)
        .background { ScreenBackground() }
        .presentationDetents([.medium])
    }
}
