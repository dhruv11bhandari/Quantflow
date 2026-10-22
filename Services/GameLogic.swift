import Foundation

struct AttemptOutcome {
    var xp = 0
    var correct = false
    var ratio = 0.0
    var mistake: MistakeCategory = .none
    var skillDeltas: [SkillKey: Double] = [:]
    var newlyMastered: [SkillKey] = []
    var unlocked: [AchievementID] = []
    var goalReached = false
    var streakIncreased = false
    var levelUp: LevelInfo? = nil
}

struct SessionReward {
    var xp = 0
    var unlocked: [AchievementID] = []
}

enum DayKey {
    static func key(_ date: Date, _ calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(_ key: String, _ calendar: Calendar = .current) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    static func daysBetween(_ a: String, _ b: String, _ calendar: Calendar = .current) -> Int? {
        guard let da = date(a, calendar), let db = date(b, calendar) else { return nil }
        return calendar.dateComponents([.day], from: da, to: db).day
    }
}

/// Pure game-state logic (XP, streaks, mastery, achievements). No UI, no persistence — easy to test anywhere.
extension SaveData {
    static let masteryThreshold = 85.0

    var dailyTarget: Int { dailyGoalMinutes * 2 }

    func topicStat(_ t: QuantTopic) -> TopicStat { topicStats[t.rawValue] ?? TopicStat() }

    // MARK: Day handling

    mutating func rollover(now: Date = Date(), calendar: Calendar = .current) {
        let k = DayKey.key(now, calendar)
        if todayKey != k {
            todayKey = k
            todayCount = 0
            todaySeconds = 0
        }
    }

    func currentStreak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let last = lastActiveDay else { return 0 }
        let today = DayKey.key(now, calendar)
        guard let gap = DayKey.daysBetween(last, today, calendar) else { return streak }
        return gap <= 1 ? streak : 0
    }

    /// Called on the first answered question of a day. Returns true when the streak counter changed.
    @discardableResult
    mutating func touchStreak(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let today = DayKey.key(now, calendar)
        if lastActiveDay == today { return false }
        if let last = lastActiveDay, let gap = DayKey.daysBetween(last, today, calendar), gap == 1 {
            streak += 1
        } else {
            streak = 1
        }
        lastActiveDay = today
        bestStreak = max(bestStreak, streak)
        return true
    }

    // MARK: Achievements

    @discardableResult
    mutating func unlock(_ id: AchievementID, now: Date = Date()) -> Bool {
        if achievements[id.rawValue] != nil { return false }
        achievements[id.rawValue] = now
        return true
    }

    func isUnlocked(_ id: AchievementID) -> Bool { achievements[id.rawValue] != nil }

    mutating func checkAchievements(correct: Bool, seconds: Double, difficulty: Int, now: Date) -> [AchievementID] {
        var new: [AchievementID] = []
        if attempts >= 100, unlock(.hundredQuestions, now: now) { new.append(.hundredQuestions) }
        if correct, seconds < 5, difficulty >= 2, unlock(.underFiveSeconds, now: now) { new.append(.underFiveSeconds) }
        if perfectRun >= 5, unlock(.firstPerfectSprint, now: now) { new.append(.firstPerfectSprint) }
        if skills.probability >= SaveData.masteryThreshold, unlock(.probabilityMaster, now: now) { new.append(.probabilityMaster) }
        if skills.expectedValue >= SaveData.masteryThreshold, unlock(.evMaster, now: now) { new.append(.evMaster) }
        if streak >= 7, unlock(.sevenDayStreak, now: now) { new.append(.sevenDayStreak) }
        return new
    }

    // MARK: Score history

    mutating func touchScoreHistory(now: Date = Date(), calendar: Calendar = .current) {
        let point = ScorePoint(date: now, value: skills.readiness)
        if let last = scoreHistory.last, calendar.isDate(last.date, inSameDayAs: now) {
            scoreHistory[scoreHistory.count - 1] = point
        } else {
            scoreHistory.append(point)
        }
        if scoreHistory.count > 60 { scoreHistory.removeFirst(scoreHistory.count - 60) }
    }

    // MARK: Recording an answer

    @discardableResult
    mutating func record(_ q: QuantQuestion, result: EvaluationResult, seconds: Double, source: AttemptSource,
                         updateSkills: Bool = true, now: Date = Date(), calendar: Calendar = .current) -> AttemptOutcome {
        rollover(now: now, calendar: calendar)
        var out = AttemptOutcome()
        let ratio = seconds / max(q.targetSeconds, 1)
        let mistake = MistakeAnalyzer.classify(correct: result.correct, skipped: result.skipped, ratio: ratio,
                                               relativeError: result.relativeError)
        out.correct = result.correct
        out.ratio = ratio
        out.mistake = mistake

        let levelBefore = ScoringEngine.level(forXP: xp)

        if updateSkills {
            let before = skills
            out.skillDeltas = AdaptiveEngine.update(skills: &skills, levels: &levels, question: q,
                                                    correct: result.correct, seconds: seconds)
            for key in SkillKey.allCases where key != .speed {
                if before[key] < SaveData.masteryThreshold, skills[key] >= SaveData.masteryThreshold,
                   !mastered.contains(key.rawValue) {
                    mastered.append(key.rawValue)
                    out.newlyMastered.append(key)
                }
            }
        }

        if result.correct {
            out.xp = ScoringEngine.xp(difficulty: q.difficulty, ratio: ratio)
        } else if !result.skipped {
            out.xp = 2
        }
        xp += out.xp

        attempts += 1
        if result.correct { correctCount += 1 }
        totalSeconds += min(seconds, 120)

        var stat = topicStats[q.topic.rawValue] ?? TopicStat()
        stat.attempts += 1
        if result.correct { stat.correct += 1 }
        stat.totalSeconds += min(seconds, 120)
        topicStats[q.topic.rawValue] = stat

        history.append(AttemptRecord(questionID: q.id, type: q.type, topic: q.topic, difficulty: q.difficulty,
                                     correct: result.correct, seconds: seconds, target: q.targetSeconds,
                                     date: now, mistake: mistake, source: source))
        if history.count > 300 { history.removeFirst(history.count - 300) }

        todayCount += 1
        todaySeconds += seconds
        out.streakIncreased = touchStreak(now: now, calendar: calendar)

        if result.correct && ratio <= 1.0 { perfectRun += 1 } else { perfectRun = 0 }

        cardCounter += 1
        AdaptiveEngine.scheduleReview(queue: &reviewQueue, question: q, correct: result.correct,
                                      mistake: mistake, cardIndex: cardCounter)

        if todayCount >= dailyTarget && goalRewardedDay != todayKey {
            goalRewardedDay = todayKey
            xp += 20
            out.goalReached = true
        }

        out.unlocked = checkAchievements(correct: result.correct, seconds: seconds, difficulty: q.difficulty, now: now)

        let levelAfter = ScoringEngine.level(forXP: xp)
        if levelAfter.index > levelBefore.index { out.levelUp = levelAfter }

        touchScoreHistory(now: now, calendar: calendar)
        return out
    }

    /// Formula / trick cards: a small XP reward the first time each card is read.
    mutating func acknowledgeRead(_ q: QuantQuestion, now: Date = Date()) -> Int {
        cardCounter += 1
        let key = "read." + q.id
        if learned.contains(key) { return 0 }
        learned.append(key)
        xp += 2
        return 2
    }

    // MARK: QuantScan

    @discardableResult
    mutating func completeScan(_ scanAttempts: [ScanAttempt], now: Date = Date(), calendar: Calendar = .current) -> ScanResult {
        for a in scanAttempts {
            let r = EvaluationResult(correct: a.correct, skipped: a.skipped, relativeError: a.relativeError, note: nil)
            record(a.question, result: r, seconds: a.seconds, source: .scan, updateSkills: false, now: now, calendar: calendar)
        }
        let result = ScoringEngine.makeScanResult(scanAttempts, now: now)
        skills = result.skills
        scan = result
        isDemo = false
        for key in SkillKey.allCases where key != .speed {
            levels[key.rawValue] = clamp(1.0 + skills[key] / 100.0 * 3.2, 1, 4.2)
            if skills[key] >= SaveData.masteryThreshold, !mastered.contains(key.rawValue) { mastered.append(key.rawValue) }
        }
        unlock(.firstScan, now: now)
        seenOpening = false
        touchScoreHistory(now: now, calendar: calendar)
        return result
    }

    // MARK: Simulations

    mutating func finishInterview(_ report: InterviewReport, now: Date = Date()) -> SessionReward {
        var reward = SessionReward()
        interviews.append(report)
        if interviews.count > 5 { interviews.removeFirst(interviews.count - 5) }
        reward.xp = 15 + report.correct * 3
        xp += reward.xp
        if report.correct == report.total && report.total > 0 { perfectRun = max(perfectRun, 5) }
        if unlock(.mockInterview, now: now) { reward.unlocked.append(.mockInterview) }
        if perfectRun >= 5, unlock(.firstPerfectSprint, now: now) { reward.unlocked.append(.firstPerfectSprint) }
        touchScoreHistory(now: now)
        return reward
    }

    mutating func finishMarketMaker(_ review: MMReview, now: Date = Date()) -> SessionReward {
        var reward = SessionReward()
        marketSessions += 1
        marketBestPnL = marketSessions == 1 ? review.totalPnL : max(marketBestPnL, review.totalPnL)
        let before = skills.marketMaking
        skills.marketMaking = before + (review.score * 100 - before) * 0.35
        reward.xp = 20 + Int((review.score * 30).rounded())
        xp += reward.xp
        touchStreak(now: now)
        if before < SaveData.masteryThreshold, skills.marketMaking >= SaveData.masteryThreshold,
           !mastered.contains(SkillKey.marketMaking.rawValue) { mastered.append(SkillKey.marketMaking.rawValue) }
        if unlock(.firstMarketMaker, now: now) { reward.unlocked.append(.firstMarketMaker) }
        touchScoreHistory(now: now)
        return reward
    }

    mutating func finishEVGame(correct: Int, total: Int, now: Date = Date()) -> SessionReward {
        var reward = SessionReward()
        evGames += 1
        evBest = max(evBest, correct)
        let before = skills.expectedValue
        let target = total == 0 ? before : Double(correct) / Double(total) * 100
        skills.expectedValue = before + (target - before) * 0.10
        reward.xp = 10 + 4 * correct
        xp += reward.xp
        touchStreak(now: now)
        if correct >= 5, unlock(.evGameWin, now: now) { reward.unlocked.append(.evGameWin) }
        if skills.expectedValue >= SaveData.masteryThreshold, unlock(.evMaster, now: now) { reward.unlocked.append(.evMaster) }
        touchScoreHistory(now: now)
        return reward
    }

    mutating func markLearned(_ key: String) -> Int {
        let k = "concept." + key
        if learned.contains(k) { return 0 }
        learned.append(k)
        xp += 6
        return 6
    }

    // MARK: Demo profile

    /// A believable, clearly-labelled demo profile so the whole app can be explored immediately.
    mutating func loadDemo(now: Date = Date(), calendar: Calendar = .current) {
        var s = SaveData()
        s.hapticsOn = hapticsOn
        s.isDemo = true
        s.skills = SkillProfile(mentalMath: 92, probability: 67, expectedValue: 59, logic: 81,
                                estimation: 78, marketMaking: 31, speed: 84)
        s.xp = 4120
        s.attempts = 2893
        s.correctCount = 2481
        s.totalSeconds = 8.7 * 2893
        s.streak = 14
        s.bestStreak = 14
        s.lastActiveDay = DayKey.key(now, calendar)
        s.todayKey = DayKey.key(now, calendar)
        s.todayCount = 12
        s.todaySeconds = 410
        s.dailyGoalMinutes = 10
        s.seenOpening = true
        s.marketSessions = 3
        s.marketBestPnL = 18.4
        s.evGames = 4
        s.evBest = 5
        for key in SkillKey.allCases where key != .speed {
            s.levels[key.rawValue] = clamp(1.0 + s.skills[key] / 100.0 * 3.2, 1, 4.2)
        }
        if s.skills.mentalMath >= SaveData.masteryThreshold { s.mastered = [SkillKey.mentalMath.rawValue] }

        let plan: [(QuantTopic, Int, Double, Double)] = [
            (.arithmetic, 520, 0.97, 5.1), (.percentages, 400, 0.95, 6.4), (.fractions, 300, 0.92, 7.2), (.ratios, 80, 0.93, 6.9),
            (.probability, 380, 0.78, 14.8), (.conditionalProbability, 120, 0.68, 19.5), (.expectedValue, 330, 0.70, 13.9),
            (.combinatorics, 90, 0.70, 17.6), (.statistics, 60, 0.68, 16.2), (.logic, 300, 0.91, 9.4),
            (.estimation, 213, 0.86, 8.8), (.marketMaking, 100, 0.55, 18.3)
        ]
        var solvedSum = 0
        for (topic, n, acc, avg) in plan {
            let right = Int((Double(n) * acc).rounded())
            s.topicStats[topic.rawValue] = TopicStat(attempts: n, correct: right, totalSeconds: avg * Double(n))
            solvedSum += right
        }
        // Spread any rounding residual across topics so the per-topic totals add up exactly.
        var residual = s.correctCount - solvedSum
        var cursor = 0
        while residual != 0 && cursor < 10_000 {
            let topic = plan[cursor % plan.count].0
            cursor += 1
            guard var stat = s.topicStats[topic.rawValue] else { continue }
            if residual > 0 && stat.correct < stat.attempts {
                stat.correct += 1
                residual -= 1
            } else if residual < 0 && stat.correct > 0 {
                stat.correct -= 1
                residual += 1
            }
            s.topicStats[topic.rawValue] = stat
        }

        let values = [52, 54, 55, 57, 58, 60, 61, 63, 64, 66, 67, 68, 70, 71]
        for (i, v) in values.enumerated() {
            let d = calendar.date(byAdding: .day, value: -(values.count - 1 - i), to: now) ?? now
            s.scoreHistory.append(ScorePoint(date: d, value: v))
        }
        for id in [AchievementID.firstScan, .hundredQuestions, .underFiveSeconds, .sevenDayStreak, .firstPerfectSprint, .firstMarketMaker, .mockInterview] {
            s.achievements[id.rawValue] = now
        }
        s.scan = ScanResult(readiness: s.skills.readiness, skills: s.skills, accuracy: 0.8, avgSeconds: 9.6, correct: 8, total: 10,
                            mistakes: ["conceptual": 1, "slow": 1], nextEdgeSkill: SkillKey.expectedValue.rawValue,
                            nextEdgeTopic: SkillKey.expectedValue.focusTopic, date: now)
        self = s
    }
}
