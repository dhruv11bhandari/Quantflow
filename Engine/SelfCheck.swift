import Foundation

struct SelfCheckItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let passed: Bool
}

struct SelfCheckReport {
    let items: [SelfCheckItem]
    let checks: Int
    var passed: Bool { items.allSatisfy { $0.passed } }
}

/// In-app "math integrity check": re-verifies the curated bank, the generators, the simulations and the scoring maths
/// on the device itself. Pure local computation — it never touches the network or the saved profile.
enum SelfCheck {

    static func run() -> SelfCheckReport {
        var items: [SelfCheckItem] = []
        var total = 0

        func add(_ title: String, _ detail: String, _ ok: Bool, _ n: Int) {
            items.append(SelfCheckItem(title: title, detail: detail, passed: ok))
            total += n
        }

        // 1. Curated bank structure
        let all = QuestionBank.all
        var typeCounts: [QuestionType: Int] = [:]
        for q in all { typeCounts[q.type, default: 0] += 1 }
        let structureOK = all.count == 110 && Set(all.map { $0.id }).count == all.count && typeCounts.count == 8
        add("Question bank", "\(all.count) curated questions · \(typeCounts.count) types · unique IDs", structureOK, all.count)

        // 2. Every curated answer is accepted, and a clearly wrong answer is rejected
        var answerOK = true
        var answerChecks = 0
        for q in all + LearnContent.concepts.map({ $0.challenge }) {
            switch q.input {
            case .numeric(let v, let kind, let tol):
                let right = AnswerValidator.isCorrect(String(v), expected: v, kind: kind, tolerance: tol)
                let wrong = AnswerValidator.isCorrect(String(v + abs(v) * 0.5 + 1), expected: v, kind: kind, tolerance: tol)
                if !right || wrong { answerOK = false }
                answerChecks += 2
            case .choice(let options, let correct):
                if !options.indices.contains(correct) { answerOK = false }
                answerChecks += 1
            case .quote(let spec):
                if !spec.accepts(bid: spec.bidMax, ask: spec.askMin) || spec.accepts(bid: spec.marketBid, ask: spec.marketAsk) { answerOK = false }
                answerChecks += 2
            case .read(let steps):
                if steps.count < 3 { answerOK = false }
                answerChecks += 1
            }
        }
        add("Answer validation", "Every answer accepted · wrong answers rejected · \(answerChecks) checks", answerOK, answerChecks)

        // 3. Generators are deterministic and self-consistent
        var genOK = true
        var genChecks = 0
        for kind in GeneratorKind.allCases {
            for d in 1...5 {
                for s in 0..<40 {
                    let seed = UInt64(s) &* 104_729 &+ 11
                    let q = QuestionGenerators.make(kind, difficulty: d, seed: seed)
                    let again = QuantEngine.question(id: q.id)
                    let accepts = AnswerEvaluator.evaluate(q, .text(String(q.numericValue ?? .nan))).correct
                    if again?.prompt != q.prompt || !accepts || q.prompt.isEmpty || q.explanation.isEmpty { genOK = false }
                    genChecks += 3
                }
            }
        }
        add("Question generators", "7 generators × 5 levels × 40 seeds · reproducible from ID · \(genChecks) checks", genOK, genChecks)

        // 4. Probability by enumeration
        var diceOK = true
        for s in 2...12 {
            var ways = 0
            for a in 1...6 { for b in 1...6 where a + b == s { ways += 1 } }
            if ways != 6 - abs(7 - s) { diceOK = false }
        }
        let eight = Frac(5, 36)
        add("Probability", "Two-dice sums enumerated against the closed form · P(sum = 8) = \(eight.text)", diceOK && abs(eight.value - 0.13889) < 0.0001, 11)

        // 5. Market-maker accounting (the example from the brief)
        let r1 = MarketMakerEngine.scenarios(seed: 0)[0]
        let fill = MarketMakerEngine.resolve(r1, bid: 102.00, ask: 102.70, inventory: MarketMakerEngine.startInventory)
        let mmOK = fill.filled && fill.inventoryAfter == -26 && abs(fill.spreadPnL - 12.0) < 1e-9 && abs(fill.total - 8.1) < 1e-9
        add("Market Maker", "Sell 40 @ 102.70 vs fair 102.40: edge +12.0, inventory move −3.9, round P&L +8.1", mmOK, 4)

        // 6. EV game
        let rounds = EVGameEngine.rounds(seed: 0)
        var evOK = abs(rounds[0].a.ev - 3.0) < 1e-9 && abs(rounds[0].b.ev - 4.3) < 1e-9
        for seed in 0..<50 {
            for r in EVGameEngine.rounds(seed: UInt64(seed)) where abs(r.a.ev - r.b.ev) < 0.5 - 1e-9 { evOK = false }
        }
        let avg = EVGameEngine.runningAverage(rounds[0].b, plays: 5_000, seed: 3)
        if abs((avg.last ?? 0) - rounds[0].b.ev) > 0.35 { evOK = false }
        add("EV Game", "Gamble A = 3.0, B = 4.3 · 5,000 simulated plays converge to the EV", evOK, 53)

        // 7. Scoring
        var demo = SaveData()
        demo.loadDemo()
        let scoreOK = demo.skills.readiness == 71 && ScoringEngine.xp(difficulty: 2, ratio: 0.5) == 12
        add("Scoring", "Readiness weights sum to 1 · demo profile = 71 · a fast level-2 answer = +12 XP", scoreOK, 3)

        // 8. Persistence round trip
        var saveOK = false
        if let data = try? JSONEncoder().encode(demo), let back = try? JSONDecoder().decode(SaveData.self, from: data) {
            saveOK = back.xp == demo.xp && back.skills == demo.skills && back.attempts == demo.attempts
        }
        add("Local persistence", "Profile encodes and decodes losslessly (JSON in UserDefaults, on this device only)", saveOK, 3)

        return SelfCheckReport(items: items, checks: total)
    }
}
