import Foundation

enum MistakeCategory: String, Codable {
    case none, slow, calculation, conceptual, stuck, skipped

    var title: String {
        switch self {
        case .none: return "Clean"
        case .slow: return "Correct, but slow"
        case .calculation: return "Close — arithmetic slip"
        case .conceptual: return "Fast and wrong — concept gap"
        case .stuck: return "Slow and wrong — needs easier reps"
        case .skipped: return "Skipped"
        }
    }
}

enum AttemptSource: String, Codable { case scan, train, interview, learn }

struct AttemptRecord: Codable, Identifiable {
    var id = UUID()
    var questionID: String
    var type: QuestionType
    var topic: QuantTopic
    var difficulty: Int
    var correct: Bool
    var seconds: Double
    var target: Double
    var date: Date
    var mistake: MistakeCategory
    var source: AttemptSource
}

struct TopicStat: Codable {
    var attempts = 0
    var correct = 0
    var totalSeconds = 0.0
    var accuracy: Double { attempts == 0 ? 0 : Double(correct) / Double(attempts) }
    var avgSeconds: Double { attempts == 0 ? 0 : totalSeconds / Double(attempts) }
}

/// Simple Leitner-style review slot. Due dates are counted in cards, because sessions are short.
struct ReviewItem: Codable {
    var questionID: String
    var box: Int
    var dueAtCard: Int
}

struct ScanResult: Codable {
    var readiness: Int
    var skills: SkillProfile
    var accuracy: Double
    var avgSeconds: Double
    var correct: Int
    var total: Int
    var mistakes: [String: Int]
    var nextEdgeSkill: String
    var nextEdgeTopic: String
    var date: Date
}

struct ScorePoint: Codable, Identifiable {
    var date: Date
    var value: Int
    var id: Double { date.timeIntervalSince1970 }
}

struct InterviewReport: Codable {
    var date: Date
    var total: Int
    var correct: Int
    var accuracy: Double
    var speed: Double
    var secondsUsed: Double
    /// Skill raw value → accuracy 0…1
    var bySkill: [String: Double]
    var focus: [String]
}

enum AchievementID: String, Codable, CaseIterable, Identifiable {
    case firstScan, firstPerfectSprint, hundredQuestions, underFiveSeconds, probabilityMaster
    case evMaster, firstMarketMaker, sevenDayStreak, mockInterview, evGameWin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstScan: return "FIRST SCAN"
        case .firstPerfectSprint: return "PERFECT SPRINT"
        case .hundredQuestions: return "100 QUESTIONS"
        case .underFiveSeconds: return "UNDER 5 SECONDS"
        case .probabilityMaster: return "PROBABILITY MASTER"
        case .evMaster: return "EV MASTER"
        case .firstMarketMaker: return "FIRST MARKET MAKER"
        case .sevenDayStreak: return "7 DAY STREAK"
        case .mockInterview: return "MOCK INTERVIEW"
        case .evGameWin: return "EV INSTINCT"
        }
    }

    var detail: String {
        switch self {
        case .firstScan: return "Finish QuantScan."
        case .firstPerfectSprint: return "Five correct answers in a row, each inside target time."
        case .hundredQuestions: return "Answer 100 questions."
        case .underFiveSeconds: return "Solve a level 2+ question correctly in under 5 seconds."
        case .probabilityMaster: return "Reach 85 mastery in Probability."
        case .evMaster: return "Reach 85 mastery in Expected Value."
        case .firstMarketMaker: return "Complete a Market Maker session."
        case .sevenDayStreak: return "Train seven days in a row."
        case .mockInterview: return "Finish a mock interview."
        case .evGameWin: return "Pick the higher EV in at least 5 of 6 EV Game rounds."
        }
    }

    var symbol: String {
        switch self {
        case .firstScan: return "scope"
        case .firstPerfectSprint: return "bolt.fill"
        case .hundredQuestions: return "number"
        case .underFiveSeconds: return "timer"
        case .probabilityMaster: return "dice"
        case .evMaster: return "scalemass"
        case .firstMarketMaker: return "chart.bar.xaxis"
        case .sevenDayStreak: return "flame.fill"
        case .mockInterview: return "briefcase"
        case .evGameWin: return "target"
        }
    }
}

/// Everything that is persisted. One Codable value, stored as JSON in UserDefaults.
struct SaveData: Codable {
    var version = 1
    var xp = 0
    var streak = 0
    var bestStreak = 0
    var lastActiveDay: String? = nil
    /// Answered questions (right or wrong).
    var attempts = 0
    /// Answered correctly — shown as "Questions solved".
    var correctCount = 0
    var totalSeconds = 0.0
    var skills = SkillProfile()
    var levels: [String: Double] = [:]
    var topicStats: [String: TopicStat] = [:]
    var history: [AttemptRecord] = []
    var reviewQueue: [ReviewItem] = []
    var cardCounter = 0
    var scan: ScanResult? = nil
    var achievements: [String: Date] = [:]
    var mastered: [String] = []
    var dailyGoalMinutes = 10
    var todayKey = ""
    var todayCount = 0
    var todaySeconds = 0.0
    var goalRewardedDay = ""
    var scoreHistory: [ScorePoint] = []
    var interviews: [InterviewReport] = []
    var marketSessions = 0
    var marketBestPnL = 0.0
    var evGames = 0
    var evBest = 0
    var learned: [String] = []
    var seenOpening = false
    var perfectRun = 0
    var isDemo = false
    var hapticsOn = true

    var hasProfile: Bool { scan != nil || isDemo }
    var questionsSolved: Int { correctCount }
    var accuracy: Double { attempts == 0 ? 0 : Double(correctCount) / Double(attempts) }
    var avgSeconds: Double { attempts == 0 ? 0 : totalSeconds / Double(attempts) }
}
