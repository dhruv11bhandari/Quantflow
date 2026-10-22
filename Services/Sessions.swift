import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - Per-card interaction state

enum CardPhase { case answering, answered }

/// Everything about one on-screen question: what the learner typed, timing, and the verdict.
/// Each card owns its own state so a card that is animating out keeps showing its own answer.
final class CardState: ObservableObject, Identifiable {
    static let quoteTick = 0.05

    let id = UUID()
    let question: QuantQuestion
    let isReview: Bool
    private(set) var startedAt = Date()

    @Published var input = ""
    @Published var choice: Int? = nil
    @Published var bid: Double
    @Published var ask: Double
    @Published var revealed = 0
    @Published var phase: CardPhase = .answering
    @Published var result: EvaluationResult? = nil
    @Published var outcome: AttemptOutcome? = nil
    @Published var elapsed = 0.0

    init(question: QuantQuestion, isReview: Bool = false) {
        self.question = question
        self.isReview = isReview
        if case .quote(let spec) = question.input {
            bid = spec.marketBid
            ask = spec.marketAsk
        } else {
            bid = 0
            ask = 0
        }
    }

    var isAnswered: Bool { phase == .answered }

    /// Called when a card comes back on screen (e.g. after visiting another tab) so away-time isn't counted.
    func restartClock() {
        if phase == .answering { startedAt = Date() }
    }

    func nudgeBid(_ steps: Int) {
        bid = round2(bid + Double(steps) * CardState.quoteTick)
        if bid >= ask - 0.0001 { bid = round2(ask - CardState.quoteTick) }
    }

    func nudgeAsk(_ steps: Int) {
        ask = round2(ask + Double(steps) * CardState.quoteTick)
        if ask <= bid + 0.0001 { ask = round2(bid + CardState.quoteTick) }
    }

    func typeKey(_ key: String) {
        guard phase == .answering else { return }
        if key == "⌫" {
            if !input.isEmpty { input.removeLast() }
        } else if input.count < 12 {
            input.append(key)
        }
    }
}

// MARK: - TRAIN feed

final class TrainSession: ObservableObject {
    @Published var current: CardState? = nil
    @Published var shownThisRun = 0
    @Published var correctThisRun = 0
    @Published var showGoalComplete = false
    @Published var masteredSkill: SkillKey? = nil

    private var recentIDs: [String] = []
    private var cardsSinceRead = 0
    private var openingIndex = 0
    private let seed: UInt64 = UInt64(Date().timeIntervalSince1970) & 0xFFFF_FFFF
    /// The first five cards after QuantScan show the whole product: math, probability, EV, formula, brainteaser.
    private let openingScript: [QuestionType] = [.mentalMath, .probability, .expectedValue, .formula, .brainteaser]

    func begin(_ model: AppModel) {
        if current == nil { current = makeNext(model) }
    }

    /// Forget the current feed (used when progress is reset or a scan is retaken).
    func reset() {
        current = nil
        shownThisRun = 0
        correctThisRun = 0
        showGoalComplete = false
        masteredSkill = nil
        recentIDs = []
        cardsSinceRead = 0
        openingIndex = 0
    }

    private func makeNext(_ model: AppModel) -> CardState {
        var force: QuestionType? = nil
        if !model.save.seenOpening && openingIndex < openingScript.count {
            force = openingScript[openingIndex]
            openingIndex += 1
            if openingIndex == openingScript.count { model.markOpeningSeen() }
        }
        let ctx = SelectionContext(skills: model.save.skills, levels: model.save.levels, recent: model.save.history,
                                   reviewQueue: model.save.reviewQueue, cardIndex: model.save.cardCounter,
                                   recentIDs: recentIDs, forceType: force, cardsSinceRead: cardsSinceRead, seed: seed)
        let sel = AdaptiveEngine.select(ctx)
        recentIDs.append(sel.question.id)
        if recentIDs.count > 40 { recentIDs.removeFirst(recentIDs.count - 40) }
        cardsSinceRead = sel.question.isReadOnly ? 0 : cardsSinceRead + 1
        return CardState(question: sel.question, isReview: sel.isReview)
    }

    func advance(_ model: AppModel) {
        current = makeNext(model)
    }

    func submit(_ answer: UserAnswer, model: AppModel) {
        guard let card = current, card.phase == .answering, !card.question.isReadOnly else { return }
        let elapsed = Date().timeIntervalSince(card.startedAt)
        let result = AnswerEvaluator.evaluate(card.question, answer)
        let outcome = model.record(card.question, result: result, seconds: elapsed, source: .train)
        card.elapsed = elapsed
        card.result = result
        card.outcome = outcome
        card.phase = .answered
        shownThisRun += 1
        if result.correct { correctThisRun += 1; Haptics.success() } else if result.skipped { Haptics.tap() } else { Haptics.error() }
        if outcome.goalReached { showGoalComplete = true }
        if let m = outcome.newlyMastered.first {
            masteredSkill = m
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in self?.masteredSkill = nil }
        }
    }

    /// Read-only cards (formulas, tricks): tap "Got it" to bank the XP.
    func acknowledge(model: AppModel) {
        guard let card = current, card.phase == .answering, card.question.isReadOnly else { return }
        let xp = model.acknowledgeRead(card.question)
        var out = AttemptOutcome()
        out.xp = xp
        out.correct = true
        card.outcome = out
        card.result = EvaluationResult(correct: true, skipped: false, relativeError: nil, note: nil)
        card.phase = .answered
        Haptics.soft()
    }
}

// MARK: - QuantScan

enum ScanPhase { case intro, question, feedback, done }

final class ScanSession: ObservableObject {
    let questions: [QuantQuestion]
    @Published var index = 0
    @Published var phase: ScanPhase = .intro
    @Published var card: CardState
    @Published var attempts: [ScanAttempt] = []
    @Published var result: ScanResult? = nil

    init() {
        let qs = QuantEngine.scanQuestions()
        questions = qs
        card = CardState(question: qs.first ?? QuestionGenerators.make(.mul, difficulty: 1, seed: 1))
    }

    var total: Int { questions.count }

    func begin() {
        guard let first = questions.first else { return }
        index = 0
        attempts = []
        result = nil
        card = CardState(question: first)
        phase = .question
    }

    func submit(_ answer: UserAnswer) {
        guard phase == .question else { return }
        let q = card.question
        let elapsed = Date().timeIntervalSince(card.startedAt)
        let eval = AnswerEvaluator.evaluate(q, answer)
        let ratio = elapsed / max(q.targetSeconds, 1)
        let mistake = MistakeAnalyzer.classify(correct: eval.correct, skipped: eval.skipped, ratio: ratio, relativeError: eval.relativeError)
        attempts.append(ScanAttempt(question: q, correct: eval.correct, skipped: eval.skipped, seconds: elapsed,
                                    relativeError: eval.relativeError, mistake: mistake))
        card.result = eval
        card.elapsed = elapsed
        card.phase = .answered
        phase = .feedback
        if eval.correct { Haptics.success() } else { Haptics.error() }
    }

    func advance(_ model: AppModel) {
        guard phase == .feedback else { return }
        if index + 1 < questions.count {
            index += 1
            card = CardState(question: questions[index])
            phase = .question
        } else {
            result = model.completeScan(attempts)
            phase = .done
        }
    }
}

// MARK: - Mock interview

enum InterviewPhase { case intro, running, report }

final class InterviewSession: ObservableObject {
    @Published var phase: InterviewPhase = .intro
    @Published var questions: [QuantQuestion] = []
    @Published var index = 0
    @Published var remaining = InterviewEngine.totalSeconds
    @Published var card: CardState? = nil
    @Published var report: InterviewReport? = nil
    @Published var reward: SessionReward? = nil

    private var correct: [Bool] = []
    private var seconds: [Double] = []
    private var startedAt = Date()
    private var finished = false

    func begin(seed: UInt64) {
        questions = InterviewEngine.makeSet(seed: seed)
        guard let first = questions.first else { return }
        index = 0
        correct = []
        seconds = []
        remaining = InterviewEngine.totalSeconds
        startedAt = Date()
        finished = false
        report = nil
        reward = nil
        card = CardState(question: first)
        phase = .running
    }

    func tick(_ model: AppModel) {
        guard phase == .running else { return }
        remaining = max(0, InterviewEngine.totalSeconds - Date().timeIntervalSince(startedAt))
        if remaining <= 0 { finish(model) }
    }

    func submit(_ answer: UserAnswer, model: AppModel) {
        guard phase == .running, let card = card else { return }
        let elapsed = Date().timeIntervalSince(card.startedAt)
        let eval = AnswerEvaluator.evaluate(card.question, answer)
        model.record(card.question, result: eval, seconds: elapsed, source: .interview)
        correct.append(eval.correct)
        seconds.append(elapsed)
        Haptics.tap()
        if index + 1 >= questions.count {
            finish(model)
        } else {
            index += 1
            self.card = CardState(question: questions[index])
        }
    }

    func finish(_ model: AppModel) {
        guard !finished else { return }
        finished = true
        let used = min(InterviewEngine.totalSeconds, Date().timeIntervalSince(startedAt))
        let r = InterviewEngine.report(questions: questions, correct: correct, seconds: seconds, used: used)
        report = r
        reward = model.finishInterview(r)
        phase = .report
        Haptics.success()
    }
}

// MARK: - Market Maker

enum MarketPhase { case intro, quoting, result, summary }

final class MarketSession: ObservableObject {
    let scenarios: [MMScenario]
    @Published var round = 0
    @Published var phase: MarketPhase = .intro
    @Published var bid: Double
    @Published var ask: Double
    @Published var inventory = MarketMakerEngine.startInventory
    @Published var results: [MMRoundResult] = []
    @Published var lastResult: MMRoundResult? = nil
    @Published var review: MMReview? = nil
    @Published var reward: SessionReward? = nil

    init(seed: UInt64) {
        let s = MarketMakerEngine.scenarios(seed: seed)
        scenarios = s
        bid = s.first?.marketBid ?? 100
        ask = s.first?.marketAsk ?? 101
    }

    var scenario: MMScenario { scenarios[min(round, scenarios.count - 1)] }
    var cumulativePnL: Double { results.reduce(0) { $0 + $1.total } }
    var canPost: Bool { bid < ask - 0.0001 }
    var isLastRound: Bool { round + 1 >= scenarios.count }

    func begin() {
        phase = .quoting
        resetQuote()
    }

    func resetQuote() {
        bid = scenario.marketBid
        ask = scenario.marketAsk
    }

    func nudgeBid(_ steps: Int) {
        bid = round2(bid + Double(steps) * CardState.quoteTick)
        if bid >= ask - 0.0001 { bid = round2(ask - CardState.quoteTick) }
    }

    func nudgeAsk(_ steps: Int) {
        ask = round2(ask + Double(steps) * CardState.quoteTick)
        if ask <= bid + 0.0001 { ask = round2(bid + CardState.quoteTick) }
    }

    func post() {
        guard phase == .quoting, canPost else { return }
        let r = MarketMakerEngine.resolve(scenario, bid: bid, ask: ask, inventory: inventory)
        results.append(r)
        lastResult = r
        inventory = r.inventoryAfter
        phase = .result
        if r.filled { Haptics.success() } else { Haptics.soft() }
    }

    func nextRound(_ model: AppModel) {
        if isLastRound {
            let rv = MarketMakerEngine.review(results, scenarios: scenarios)
            review = rv
            reward = model.finishMarketMaker(rv)
            phase = .summary
        } else {
            round += 1
            lastResult = nil
            phase = .quoting
            resetQuote()
        }
    }
}

// MARK: - EV Game

enum EVPhase { case intro, choosing, reveal, summary }

final class EVGameSession: ObservableObject {
    let rounds: [EVRound]
    let playCount = 240
    @Published var index = 0
    @Published var phase: EVPhase = .intro
    @Published var picked: GameChoice? = nil
    @Published var correctCount = 0
    @Published var plays = 0
    @Published var reward: SessionReward? = nil
    @Published private(set) var seriesA: [Double] = []
    @Published private(set) var seriesB: [Double] = []

    init(seed: UInt64) {
        rounds = EVGameEngine.rounds(seed: seed)
    }

    var round: EVRound { rounds[min(index, rounds.count - 1)] }
    var wasCorrect: Bool { picked == round.better }

    func begin() { phase = .choosing }

    func pick(_ choice: GameChoice) {
        guard phase == .choosing else { return }
        picked = choice
        if choice == round.better { correctCount += 1; Haptics.success() } else { Haptics.error() }
        seriesA = EVGameEngine.runningAverage(round.a, plays: playCount, seed: UInt64(index) &* 977 &+ 11)
        seriesB = EVGameEngine.runningAverage(round.b, plays: playCount, seed: UInt64(index) &* 977 &+ 503)
        plays = 0
        phase = .reveal
    }

    func tick() {
        if phase == .reveal && plays < playCount { plays = min(playCount, plays + 4) }
    }

    func next(_ model: AppModel) {
        if index + 1 < rounds.count {
            index += 1
            picked = nil
            phase = .choosing
        } else {
            reward = model.finishEVGame(correct: correctCount, total: rounds.count)
            phase = .summary
        }
    }
}
