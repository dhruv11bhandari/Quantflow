import Foundation

// MARK: - Question taxonomy

enum QuestionType: String, Codable, CaseIterable {
    case mentalMath, probability, expectedValue, brainteaser, estimation, formula, marketMaking, interview

    var title: String {
        switch self {
        case .mentalMath: return "MENTAL MATH"
        case .probability: return "PROBABILITY"
        case .expectedValue: return "EXPECTED VALUE"
        case .brainteaser: return "BRAINTEASER"
        case .estimation: return "ESTIMATION"
        case .formula: return "FORMULA"
        case .marketMaking: return "MARKET MAKING"
        case .interview: return "INTERVIEW MODE"
        }
    }

    var symbol: String {
        switch self {
        case .mentalMath: return "multiply"
        case .probability: return "dice"
        case .expectedValue: return "scalemass"
        case .brainteaser: return "puzzlepiece.extension"
        case .estimation: return "scope"
        case .formula: return "function"
        case .marketMaking: return "chart.bar.xaxis"
        case .interview: return "briefcase"
        }
    }
}

enum QuantTopic: String, Codable, CaseIterable {
    case arithmetic, percentages, fractions, ratios, probability, conditionalProbability
    case expectedValue, combinatorics, statistics, logic, estimation, marketMaking

    var title: String {
        switch self {
        case .arithmetic: return "Arithmetic"
        case .percentages: return "Percentages"
        case .fractions: return "Fractions"
        case .ratios: return "Ratios"
        case .probability: return "Probability"
        case .conditionalProbability: return "Conditional probability"
        case .expectedValue: return "Expected value"
        case .combinatorics: return "Combinatorics"
        case .statistics: return "Statistics"
        case .logic: return "Logic"
        case .estimation: return "Estimation"
        case .marketMaking: return "Market making"
        }
    }

    var skill: SkillKey {
        switch self {
        case .arithmetic, .percentages, .fractions, .ratios: return .mentalMath
        case .probability, .conditionalProbability, .combinatorics, .statistics: return .probability
        case .expectedValue: return .expectedValue
        case .logic: return .logic
        case .estimation: return .estimation
        case .marketMaking: return .marketMaking
        }
    }
}

// MARK: - Skills

enum SkillKey: String, Codable, CaseIterable, Identifiable {
    case mentalMath, probability, expectedValue, logic, estimation, marketMaking, speed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mentalMath: return "MENTAL MATH"
        case .probability: return "PROBABILITY"
        case .expectedValue: return "EXPECTED VALUE"
        case .logic: return "LOGIC"
        case .estimation: return "ESTIMATION"
        case .marketMaking: return "MARKET MAKING"
        case .speed: return "SPEED"
        }
    }

    var name: String {
        switch self {
        case .mentalMath: return "Mental Math"
        case .probability: return "Probability"
        case .expectedValue: return "Expected Value"
        case .logic: return "Logic"
        case .estimation: return "Estimation"
        case .marketMaking: return "Market Making"
        case .speed: return "Speed"
        }
    }

    /// Short label for the radar chart.
    var short: String {
        switch self {
        case .mentalMath: return "Math"
        case .probability: return "Prob"
        case .expectedValue: return "EV"
        case .logic: return "Logic"
        case .estimation: return "Estim"
        case .marketMaking: return "Market"
        case .speed: return "Speed"
        }
    }

    /// The topic a learner should drill when this skill is their weakest.
    var focusTopic: String {
        switch self {
        case .mentalMath: return "Near-round multiplication"
        case .probability: return "Conditional probability"
        case .expectedValue: return "Expected value"
        case .logic: return "Pattern logic"
        case .estimation: return "Order-of-magnitude estimation"
        case .marketMaking: return "Quoting around fair value"
        case .speed: return "Speed under pressure"
        }
    }
}

/// Mastery per skill on a 0–100 scale. Updated after every attempt by `AdaptiveEngine`.
struct SkillProfile: Codable, Equatable {
    var mentalMath: Double = 50
    var probability: Double = 50
    var expectedValue: Double = 50
    var logic: Double = 50
    var estimation: Double = 50
    var marketMaking: Double = 30
    var speed: Double = 50

    subscript(key: SkillKey) -> Double {
        get {
            switch key {
            case .mentalMath: return mentalMath
            case .probability: return probability
            case .expectedValue: return expectedValue
            case .logic: return logic
            case .estimation: return estimation
            case .marketMaking: return marketMaking
            case .speed: return speed
            }
        }
        set {
            let v = clamp(newValue, 0, 100)
            switch key {
            case .mentalMath: mentalMath = v
            case .probability: probability = v
            case .expectedValue: expectedValue = v
            case .logic: logic = v
            case .estimation: estimation = v
            case .marketMaking: marketMaking = v
            case .speed: speed = v
            }
        }
    }

    var readiness: Int { ScoringEngine.readiness(self) }
}

// MARK: - Answer handling

/// How strictly a typed numeric answer is compared with the expected value.
enum Tolerance {
    case exact
    case absolute(Double)
    case relative(Double)
}

enum AnswerKind {
    case number
    /// Expected value is in 0…1. "5/36", "0.139", "13.9" and "13.9%" are all accepted.
    case probability
}

enum UserAnswer {
    case text(String)
    case choice(Int)
    case quote(bid: Double, ask: Double)
    case skipped
}

struct EvaluationResult {
    let correct: Bool
    let skipped: Bool
    /// Relative distance from the expected numeric answer (nil for non-numeric questions).
    let relativeError: Double?
    let note: String?
}

// MARK: - Market primitives shared by questions and the simulator

enum Volatility: String, Codable, CaseIterable {
    case low, medium, high

    var title: String { rawValue.uppercased() }

    /// One-round standard deviation of the fair value, in price units.
    var sigma: Double {
        switch self {
        case .low: return 0.15
        case .medium: return 0.35
        case .high: return 0.60
        }
    }
}

enum Side: String, Codable {
    case buy, sell
    var title: String { self == .buy ? "BUY" : "SELL" }
}

struct GambleLeg: Equatable {
    let probability: Double
    let payoff: Double
}

enum QuestionVisual {
    case none
    case gamble([GambleLeg])
}

struct QuoteSpec {
    let asset: String
    let fair: Double
    let marketBid: Double
    let marketAsk: Double
    let inventory: Int
    let volatility: Volatility
    let bidMin: Double
    let bidMax: Double
    let askMin: Double
    let askMax: Double
    let rule: String

    func accepts(bid: Double, ask: Double) -> Bool {
        let e = 0.0001
        return bid >= bidMin - e && bid <= bidMax + e && ask >= askMin - e && ask <= askMax + e && bid < ask
    }
}
