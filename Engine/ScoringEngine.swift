import Foundation

struct ScanAttempt {
    let question: QuantQuestion
    let correct: Bool
    let skipped: Bool
    let seconds: Double
    let relativeError: Double?
    let mistake: MistakeCategory
}

struct LevelInfo {
    let index: Int
    let name: String
    let floorXP: Int
    let nextXP: Int?
    /// 0…1 progress to the next level (1 at the top level).
    let progress: Double
}

/// All scoring is local and deterministic. "Training score" only — never a hiring prediction.
enum ScoringEngine {

    // MARK: Readiness

    static let readinessWeights: [SkillKey: Double] = [
        .mentalMath: 0.18, .probability: 0.20, .expectedValue: 0.18, .logic: 0.12,
        .estimation: 0.10, .marketMaking: 0.10, .speed: 0.12
    ]

    static func readiness(_ p: SkillProfile) -> Int {
        var total = 0.0
        for key in SkillKey.allCases { total += (readinessWeights[key] ?? 0) * p[key] }
        return Int(clamp(total, 0, 99).rounded())
    }

    // MARK: Speed

    /// 1.0 when the answer arrives within 60% of the target time, falling linearly to 0 at 200%.
    static func speedScore(ratio: Double) -> Double {
        clamp((2.0 - ratio) / (2.0 - 0.6), 0, 1)
    }

    // MARK: XP and levels

    static func xp(difficulty: Int, ratio: Double) -> Int {
        6 + 2 * difficulty + (ratio <= 1.0 ? 2 : 0)
    }

    static let levelTable: [(name: String, floor: Int)] = [
        ("NUMBER SENSE", 0), ("MENTAL MATH", 250), ("PROBABILITY", 700),
        ("QUANT THINKER", 1500), ("TRADING", 3000), ("QUANT", 5500)
    ]

    static func level(forXP xp: Int) -> LevelInfo {
        var idx = 0
        for (i, tier) in levelTable.enumerated() where xp >= tier.floor { idx = i }
        let cur = levelTable[idx]
        if idx + 1 < levelTable.count {
            let next = levelTable[idx + 1].floor
            let progress = Double(xp - cur.floor) / Double(next - cur.floor)
            return LevelInfo(index: idx, name: cur.name, floorXP: cur.floor, nextXP: next, progress: clamp(progress, 0, 1))
        }
        return LevelInfo(index: idx, name: cur.name, floorXP: cur.floor, nextXP: nil, progress: 1)
    }

    // MARK: QuantScan

    /// Turns the diagnostic attempts into a skill profile. Each skill is a difficulty-weighted accuracy,
    /// blended with a weak prior so one question cannot swing a score to an extreme.
    static func scanProfile(_ attempts: [ScanAttempt]) -> SkillProfile {
        var p = SkillProfile()
        let priors: [SkillKey: Double] = [.mentalMath: 50, .probability: 50, .expectedValue: 50,
                                          .logic: 50, .estimation: 50, .marketMaking: 35]
        for skill in SkillKey.allCases where skill != .speed {
            let prior = priors[skill] ?? 50
            var wSum = 0.8
            var vSum = 0.8 * prior / 100
            for a in attempts where a.question.skills.contains(skill) {
                let w = 0.6 + 0.2 * Double(a.question.difficulty)
                let ratio = a.seconds / max(a.question.targetSeconds, 1)
                let v = a.correct ? (0.7 + 0.3 * speedScore(ratio: ratio)) : 0
                wSum += w
                vSum += w * v
            }
            p[skill] = clamp(100 * vSum / wSum, 5, 98)
        }
        var sSum = 0.6 * 0.5
        var sN = 0.6
        for a in attempts {
            let ratio = a.seconds / max(a.question.targetSeconds, 1)
            sSum += a.correct ? speedScore(ratio: ratio) : 0
            sN += 1
        }
        p.speed = clamp(100 * sSum / sN, 5, 98)
        return p
    }

    static func makeScanResult(_ attempts: [ScanAttempt], now: Date = Date()) -> ScanResult {
        let skills = scanProfile(attempts)
        let correct = attempts.filter { $0.correct }.count
        let avg = attempts.isEmpty ? 0 : attempts.map { $0.seconds }.reduce(0, +) / Double(attempts.count)
        var mistakes: [String: Int] = [:]
        for a in attempts where a.mistake != .none { mistakes[a.mistake.rawValue, default: 0] += 1 }
        let edge = nextEdge(skills)
        return ScanResult(readiness: skills.readiness, skills: skills,
                          accuracy: attempts.isEmpty ? 0 : Double(correct) / Double(attempts.count),
                          avgSeconds: avg, correct: correct, total: attempts.count, mistakes: mistakes,
                          nextEdgeSkill: edge.rawValue, nextEdgeTopic: edge.focusTopic, date: now)
    }

    /// The weakest *interview* skill (market making is trained separately in the simulator).
    static func nextEdge(_ p: SkillProfile) -> SkillKey {
        let core: [SkillKey] = [.probability, .expectedValue, .mentalMath, .logic, .estimation]
        return core.min(by: { p[$0] < p[$1] }) ?? .probability
    }

    static func weakest(_ p: SkillProfile, count: Int, among: [SkillKey]) -> [SkillKey] {
        Array(among.sorted { p[$0] < p[$1] }.prefix(count))
    }
}

// MARK: - Mistake classification

enum MistakeAnalyzer {
    static func classify(correct: Bool, skipped: Bool, ratio: Double, relativeError: Double?) -> MistakeCategory {
        if correct { return ratio > 1.0 ? .slow : .none }
        if skipped { return .skipped }
        if let e = relativeError, e <= 0.10 { return .calculation }
        if ratio <= 0.6 { return .conceptual }
        return .stuck
    }
}
