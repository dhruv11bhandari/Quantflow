import SwiftUI

/// PROFILE: skills, level, achievements, settings and the in-app math integrity check.
struct ProfileScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var train: TrainSession
    @State private var confirmReset = false
    @State private var confirmDemo = false
    @State private var confirmRetake = false
    @State private var report: SelfCheckReport? = nil

    private let columns: [GridItem] = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    skillsCard
                    statsRow
                    achievements
                    settings
                    integrity
                    about
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .qfColumn()
        }
        .alert("Reset all progress?", isPresented: $confirmReset, actions: {
            Button("Reset", role: .destructive) { train.reset(); model.resetAll() }
            Button("Cancel", role: .cancel) {}
        }, message: { Text("This clears your profile, XP, streak and history on this device.") })
        .alert("Load the demo profile?", isPresented: $confirmDemo, actions: {
            Button("Load demo", role: .destructive) { model.loadDemo(); train.reset() }
            Button("Cancel", role: .cancel) {}
        }, message: { Text("This replaces your current progress with sample data so you can explore every screen.") })
        .alert("Retake QuantScan?", isPresented: $confirmRetake, actions: {
            Button("Retake", role: .destructive) { train.reset(); model.clearScanForRetake() }
            Button("Cancel", role: .cancel) {}
        }, message: { Text("You'll answer ten new diagnostic questions and your skill profile will be recalculated.") })
    }

    // MARK: Header + skills

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("YOUR QUANT PROFILE").qfLabel(Theme.accent)
                Spacer()
                if model.save.isDemo { Text("DEMO DATA").qfLabel(Theme.warn) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(model.readiness)").qf(72, .bold, design: .rounded, relativeTo: .largeTitle).foregroundStyle(Theme.text)
                VStack(alignment: .leading, spacing: 2) {
                    Text("QUANTFLOW SCORE").qfLabel(Theme.accent)
                    Text("Training score, not a hiring prediction.").qf(12, .regular, relativeTo: .caption).foregroundStyle(Theme.textDim)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.top, 14)
    }

    private var skillsCard: some View {
        VStack(spacing: 14) {
            ForEach(SkillKey.allCases) { key in
                SkillBarRow(name: key.title, value: model.skills[key])
            }
        }
        .qfCard(padding: 18, radius: 22)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: Fmt.grouped(model.save.questionsSolved), caption: "QUESTIONS")
            StatTile(value: "\(model.streak)", caption: "DAY STREAK", symbol: "flame.fill")
            StatTile(value: Fmt.num(model.save.avgSeconds, maxDecimals: 1) + "s", caption: "AVG")
        }
    }

    // MARK: Achievements

    private func tile(_ a: AchievementID) -> some View {
        let unlocked = model.save.isUnlocked(a)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: a.symbol).qf(18, .semibold).foregroundStyle(unlocked ? Theme.accent : Theme.textDim)
                Spacer()
                Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.fill").qf(13, .semibold)
                    .foregroundStyle(unlocked ? Theme.accent : Theme.textDim)
            }
            Text(a.title).qfLabel(unlocked ? Theme.text : Theme.textDim)
            Text(a.detail).qf(12, .regular, relativeTo: .caption).foregroundStyle(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qfCard(padding: 14, radius: 18, fill: unlocked ? Theme.surfaceHigh : Theme.surface)
        .opacity(unlocked ? 1.0 : 0.75)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(a.title). \(unlocked ? "Unlocked" : "Locked"). \(a.detail)")
    }

    private var achievements: some View {
        let unlockedCount = AchievementID.allCases.filter { model.save.isUnlocked($0) }.count
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "ACHIEVEMENTS", trailing: "\(unlockedCount) / \(AchievementID.allCases.count)")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AchievementID.allCases) { a in
                    tile(a)
                }
            }
        }
    }

    // MARK: Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SETTINGS").qfLabel()
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily goal").qf(15, .semibold, relativeTo: .subheadline).foregroundStyle(Theme.text)
                SegmentedChoice(options: [5, 10, 15],
                                selection: Binding(get: { model.save.dailyGoalMinutes }, set: { model.setDailyGoal(minutes: $0) }),
                                title: { "\($0) MIN" })
            }
            Toggle("Haptic feedback", isOn: Binding(get: { model.save.hapticsOn }, set: { model.setHaptics($0) }))
                .tint(Theme.accent)
                .qf(15, .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.text)
            Divider()
            SecondaryButton(title: "RETAKE QUANTSCAN", symbol: "scope") { confirmRetake = true }
            SecondaryButton(title: model.save.isDemo ? "RELOAD DEMO PROFILE" : "LOAD DEMO PROFILE", symbol: "sparkles") {
                if model.save.isDemo || !model.hasProfile { model.loadDemo(); train.reset() } else { confirmDemo = true }
            }
            SecondaryButton(title: "RESET ALL PROGRESS", symbol: "trash", tint: Theme.bad) { confirmReset = true }
        }
        .qfCard(padding: 18, radius: 22)
    }

    // MARK: Integrity check

    private var integrity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MATH INTEGRITY CHECK").qfLabel()
            Text("Re-verifies every curated answer, the question generators, the simulations and the scoring maths on this device.")
                .qf(14, .regular, relativeTo: .subheadline).foregroundStyle(Theme.textDim).fixedSize(horizontal: false, vertical: true)
            if let r = report {
                HStack(spacing: 8) {
                    Image(systemName: r.passed ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .qf(18, .semibold).foregroundStyle(r.passed ? Theme.accent : Theme.bad)
                    Text(r.passed ? "ALL \(Fmt.grouped(r.checks)) CHECKS PASSED" : "SOME CHECKS FAILED")
                        .qf(15, .bold, design: .monospaced, relativeTo: .subheadline)
                        .foregroundStyle(r.passed ? Theme.accent : Theme.bad)
                }
                .accessibilityElement(children: .combine)
                ForEach(r.items) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: item.passed ? "checkmark" : "xmark").qf(12, .bold)
                            .foregroundStyle(item.passed ? Theme.accent : Theme.bad).frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).qf(14, .semibold, relativeTo: .subheadline).foregroundStyle(Theme.text)
                            Text(item.detail).qf(12, .regular, relativeTo: .caption).foregroundStyle(Theme.textDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.title): \(item.passed ? "passed" : "failed"). \(item.detail)")
                }
            }
            SecondaryButton(title: report == nil ? "RUN THE CHECK" : "RUN AGAIN", symbol: "checkmark.shield") {
                withAnimation(Motion.spring) { report = SelfCheck.run() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qfCard(padding: 18, radius: 22)
    }

    // MARK: About

    private var about: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ABOUT").qfLabel()
            Text("QuantFlow is an educational training app. Everything runs on this device: no account, no network, no tracking.")
                .qf(13, .regular, relativeTo: .footnote).foregroundStyle(Theme.textDim).fixedSize(horizontal: false, vertical: true)
            Text("Simulations are educational models, not financial advice. The readiness number is a QuantFlow training score, not a prediction of any hiring outcome.")
                .qf(13, .regular, relativeTo: .footnote).foregroundStyle(Theme.textDim).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qfCard(padding: 16, radius: 20)
    }
}
