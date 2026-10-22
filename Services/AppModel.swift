import Foundation
#if canImport(Combine)
import Combine
#endif

struct Banner: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
}

/// App-wide store: owns the persisted `SaveData`, applies the pure game logic to it, and saves after every change.
/// Persistence is a single Codable JSON blob in UserDefaults — fully local, no network.
final class AppModel: ObservableObject {
    @Published private(set) var save: SaveData
    @Published var banner: Banner? = nil

    private let defaults: UserDefaults
    private let storageKey = "quantflow.save.v1"
    private var bannerQueue: [Banner] = []
    private var bannerBusy = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loaded = SaveData()
        if let data = defaults.data(forKey: storageKey), let decoded = try? JSONDecoder().decode(SaveData.self, from: data) {
            loaded = decoded
        }
        loaded.rollover()
        save = loaded
        Haptics.enabled = loaded.hapticsOn
    }

    // MARK: Derived values

    var skills: SkillProfile { save.skills }
    var readiness: Int { save.skills.readiness }
    var level: LevelInfo { ScoringEngine.level(forXP: save.xp) }
    var streak: Int { save.currentStreak() }
    var hasProfile: Bool { save.hasProfile }

    // MARK: Mutation plumbing

    private func commit<T>(_ change: (inout SaveData) -> T) -> T {
        var copy = save
        let result = change(&copy)
        save = copy
        persist()
        return result
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(save) { defaults.set(data, forKey: storageKey) }
    }

    // MARK: Banners

    func showBanner(_ b: Banner) {
        bannerQueue.append(b)
        drainBanners()
    }

    private func drainBanners() {
        if bannerBusy || bannerQueue.isEmpty { return }
        bannerBusy = true
        banner = bannerQueue.removeFirst()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            guard let self = self else { return }
            self.banner = nil
            self.bannerBusy = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.drainBanners() }
        }
    }

    private func announce(_ unlocked: [AchievementID], levelUp: LevelInfo? = nil) {
        if let l = levelUp { showBanner(Banner(title: "LEVEL UP", subtitle: l.name, symbol: "arrow.up.circle.fill")) }
        for a in unlocked { showBanner(Banner(title: "ACHIEVEMENT UNLOCKED", subtitle: a.title, symbol: a.symbol)) }
    }

    // MARK: Game actions

    @discardableResult
    func record(_ q: QuantQuestion, result: EvaluationResult, seconds: Double, source: AttemptSource) -> AttemptOutcome {
        let outcome = commit { $0.record(q, result: result, seconds: seconds, source: source) }
        announce(outcome.unlocked, levelUp: outcome.levelUp)
        return outcome
    }

    @discardableResult
    func acknowledgeRead(_ q: QuantQuestion) -> Int {
        commit { $0.acknowledgeRead(q) }
    }

    @discardableResult
    func completeScan(_ attempts: [ScanAttempt]) -> ScanResult {
        let result = commit { $0.completeScan(attempts) }
        announce([.firstScan])
        return result
    }

    func finishInterview(_ report: InterviewReport) -> SessionReward {
        let reward = commit { $0.finishInterview(report) }
        announce(reward.unlocked)
        return reward
    }

    func finishMarketMaker(_ review: MMReview) -> SessionReward {
        let reward = commit { $0.finishMarketMaker(review) }
        announce(reward.unlocked)
        return reward
    }

    func finishEVGame(correct: Int, total: Int) -> SessionReward {
        let reward = commit { $0.finishEVGame(correct: correct, total: total) }
        announce(reward.unlocked)
        return reward
    }

    @discardableResult
    func markLearned(_ conceptID: String) -> Int {
        commit { $0.markLearned(conceptID) }
    }

    func markOpeningSeen() { commit { $0.seenOpening = true } }

    func setDailyGoal(minutes: Int) { commit { $0.dailyGoalMinutes = minutes } }

    func setHaptics(_ on: Bool) {
        Haptics.enabled = on
        commit { $0.hapticsOn = on }
    }

    func loadDemo() { commit { $0.loadDemo() } }

    /// Wipes all progress (keeps the haptics preference).
    func resetAll() {
        commit { s in
            let h = s.hapticsOn
            s = SaveData()
            s.hapticsOn = h
        }
    }

    func clearScanForRetake() {
        commit { $0.scan = nil; $0.isDemo = false }
    }
}
