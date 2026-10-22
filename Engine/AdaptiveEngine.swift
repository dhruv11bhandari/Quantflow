import Foundation

struct SelectionContext {
    var skills: SkillProfile
    var levels: [String: Double]
    var recent: [AttemptRecord]
    var reviewQueue: [ReviewItem]
    var cardIndex: Int
    var recentIDs: [String]
    var forceType: QuestionType?
    var cardsSinceRead: Int
    var seed: UInt64
}

struct Selection {
    let question: QuantQuestion
    let isReview: Bool
}

/// Local, deterministic personalisation: mastery updates plus next-question selection.
/// Inputs: weakness, recent mistakes, difficulty level, response time, topic, spaced-review status.
enum AdaptiveEngine {

    static let defaultLevel = 2.0
    static let reviewIntervals = [4, 10, 25, 60]
    static let feedSkills: [SkillKey] = [.mentalMath, .probability, .expectedValue, .logic, .estimation, .marketMaking]

    static func level(_ levels: [String: Double], _ key: SkillKey) -> Double { levels[key.rawValue] ?? defaultLevel }

    // MARK: Mastery update

    /// correct + fast → increase · correct + slow → small increase ·
    /// incorrect + fast → likely conceptual mistake (bigger drop, review soon) ·
    /// incorrect + slow → ease the difficulty.
    @discardableResult
    static func update(skills: inout SkillProfile, levels: inout [String: Double],
                       question q: QuantQuestion, correct: Bool, seconds: Double) -> [SkillKey: Double] {
        var deltas: [SkillKey: Double] = [:]
        if q.isReadOnly { return deltas }
        let ratio = seconds / max(q.targetSeconds, 1)
        let dw = 0.8 + 0.1 * Double(q.difficulty)

        for key in q.skills {
            let m = skills[key]
            var delta: Double
            var lvl: Double
            if correct {
                if ratio <= 1.0 { delta = (100 - m) * 0.07 * dw; lvl = 0.20 }
                else if ratio <= 2.0 { delta = (100 - m) * 0.02 * dw; lvl = 0.05 }
                else { delta = (100 - m) * 0.008; lvl = 0 }
            } else {
                if ratio <= 0.6 { delta = -m * 0.05 * dw; lvl = -0.05 }
                else { delta = -m * 0.02; lvl = -0.30 }
            }
            skills[key] = m + delta
            levels[key.rawValue] = clamp(level(levels, key) + lvl, 1, 5)
            deltas[key] = skills[key] - m
        }

        let s = skills.speed
        var sDelta = 0.0
        if correct {
            if ratio <= 0.7 { sDelta = (100 - s) * 0.04 } else if ratio > 1.3 { sDelta = -s * 0.02 }
        } else {
            sDelta = -s * 0.015
        }
        skills.speed = s + sDelta
        deltas[.speed] = skills.speed - s
        return deltas
    }

    // MARK: Spaced review

    static func scheduleReview(queue: inout [ReviewItem], question q: QuantQuestion, correct: Bool,
                               mistake: MistakeCategory, cardIndex: Int) {
        if q.isReadOnly { return }
        let idx = queue.firstIndex { $0.questionID == q.id }
        if !correct {
            let due = cardIndex + (mistake == .conceptual ? 3 : 5)
            if let i = idx {
                queue[i].box = 0
                queue[i].dueAtCard = due
            } else {
                queue.append(ReviewItem(questionID: q.id, box: 0, dueAtCard: due))
            }
            if queue.count > 30 { queue.removeFirst(queue.count - 30) }
        } else if let i = idx {
            let next = queue[i].box + 1
            if next >= reviewIntervals.count {
                queue.remove(at: i)
            } else {
                queue[i].box = next
                queue[i].dueAtCard = cardIndex + reviewIntervals[next]
            }
        }
    }

    // MARK: Selection

    static func select(_ c: SelectionContext) -> Selection {
        var rng = SeededRNG(seed: c.seed &+ UInt64(max(c.cardIndex, 0)) &* 7919 &+ 17)

        if c.forceType == nil {
            let blocked = Set(c.recentIDs.suffix(4))
            let due = c.reviewQueue.filter { $0.dueAtCard <= c.cardIndex && !blocked.contains($0.questionID) }
                                   .sorted { $0.dueAtCard < $1.dueAtCard }
            for item in due {
                if let q = QuantEngine.question(id: item.questionID) { return Selection(question: q, isReview: true) }
            }
        }

        if let type = c.forceType {
            if type == .formula { return Selection(question: pickRead(c, &rng), isReview: false) }
            return Selection(question: pickQuestion(type, c, &rng), isReview: false)
        }
        if c.cardsSinceRead >= 6 { return Selection(question: pickRead(c, &rng), isReview: false) }

        let skill = pickSkill(c, &rng)
        let type = typeFor(skill, c, &rng)
        return Selection(question: pickQuestion(type, c, &rng), isReview: false)
    }

    static func primaryType(_ key: SkillKey) -> QuestionType {
        switch key {
        case .mentalMath: return .mentalMath
        case .probability: return .probability
        case .expectedValue: return .expectedValue
        case .logic: return .brainteaser
        case .estimation: return .estimation
        case .marketMaking: return .marketMaking
        case .speed: return .mentalMath
        }
    }

    static func skillFor(_ type: QuestionType) -> SkillKey {
        switch type {
        case .mentalMath, .formula: return .mentalMath
        case .probability, .interview: return .probability
        case .expectedValue: return .expectedValue
        case .brainteaser: return .logic
        case .estimation: return .estimation
        case .marketMaking: return .marketMaking
        }
    }

    private static func pickSkill(_ c: SelectionContext, _ rng: inout SeededRNG) -> SkillKey {
        let lastTypes = c.recent.suffix(2).map { $0.type }
        let lastTwelve = c.recent.suffix(12)
        var weights: [Double] = []
        for k in feedSkills {
            let weakness = 1 - c.skills[k] / 100
            let misses = lastTwelve.filter { $0.topic.skill == k && !$0.correct }.count
            var w = 0.12 + pow(max(weakness, 0), 1.5) + 0.12 * Double(misses)
            if k == .marketMaking { w *= 0.35 }
            let t = primaryType(k)
            if lastTypes.count == 2 && lastTypes[0] == t && lastTypes[1] == t { w *= 0.05 }
            else if lastTypes.last == t { w *= 0.5 }
            weights.append(w)
        }
        let total = weights.reduce(0, +)
        var r = rng.double() * total
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return feedSkills[i] }
        }
        return feedSkills[0]
    }

    private static func typeFor(_ skill: SkillKey, _ c: SelectionContext, _ rng: inout SeededRNG) -> QuestionType {
        if skill == .probability && level(c.levels, .probability) >= 3 && rng.chance(0.25) { return .interview }
        return primaryType(skill)
    }

    private static func pickQuestion(_ type: QuestionType, _ c: SelectionContext, _ rng: inout SeededRNG) -> QuantQuestion {
        let skill = skillFor(type)
        let target = clamp(Int(level(c.levels, skill).rounded()), 1, 5)
        let blocked = Set(c.recentIDs)
        var pool = QuantEngine.curated(of: type).filter { !blocked.contains($0.id) }
        let curatedCount = pool.count
        for kind in QuantEngine.generators(for: type) {
            for dd in [target - 1, target, target + 1] where dd >= 1 && dd <= 5 {
                pool.append(QuestionGenerators.make(kind, difficulty: dd, seed: rng.next() & 0x0FFF_FFFF))
            }
        }
        if pool.isEmpty {
            return QuantEngine.curated(of: type).first ?? QuestionGenerators.make(.mul, difficulty: 1, seed: 1)
        }
        var best = pool[0]
        var bestScore = Double.infinity
        for (i, q) in pool.enumerated() {
            let generated = i >= curatedCount
            let s = Double(abs(q.difficulty - target)) + rng.double() * 0.9 - (generated ? 0 : 0.15)
            if s < bestScore { bestScore = s; best = q }
        }
        return best
    }

    private static func pickRead(_ c: SelectionContext, _ rng: inout SeededRNG) -> QuantQuestion {
        let blocked = Set(c.recentIDs)
        let all = QuantEngine.readCards()
        let fresh = all.filter { !blocked.contains($0.id) }
        let weakest = ScoringEngine.nextEdge(c.skills)
        let targeted = fresh.filter { $0.topic.skill == weakest }
        let pool = targeted.isEmpty ? (fresh.isEmpty ? all : fresh) : targeted
        return pool.isEmpty ? QuestionGenerators.make(.mul, difficulty: 1, seed: 1) : rng.pick(pool)
    }
}

// MARK: - Facade

enum QuantEngine {
    static let bank: [String: QuantQuestion] = {
        var d: [String: QuantQuestion] = [:]
        for q in QuestionBank.all { d[q.id] = q }
        return d
    }()

    static func question(id: String) -> QuantQuestion? {
        if let q = bank[id] { return q }
        if let g = QuestionGenerators.parse(id: id) { return QuestionGenerators.make(g.kind, difficulty: g.difficulty, seed: g.seed) }
        return nil
    }

    static func curated(of type: QuestionType) -> [QuantQuestion] {
        QuestionBank.all.filter { $0.type == type && !$0.isReadOnly }
    }

    static func readCards() -> [QuantQuestion] { QuestionBank.all.filter { $0.isReadOnly } }

    static func generators(for type: QuestionType) -> [GeneratorKind] {
        switch type {
        case .mentalMath: return [.mul, .pct, .frac]
        case .probability: return [.prob]
        case .expectedValue: return [.ev]
        case .brainteaser: return [.seq]
        case .estimation: return [.est]
        case .interview, .formula, .marketMaking: return []
        }
    }

    static func scanQuestions() -> [QuantQuestion] { QuestionBank.scanIDs.compactMap { bank[$0] } }
}
