import Foundation

@inline(__always) func round2(_ x: Double) -> Double { (x * 100).rounded() / 100 }

// MARK: - Market Maker

struct IncomingOrder: Equatable {
    /// The aggressor's side. A BUY order lifts the market maker's offer; a SELL order hits the bid.
    let side: Side
    let size: Int
    let limit: Double
    let informed: Bool
}

struct MMScenario: Identifiable {
    let id: Int
    let asset: String
    let fair: Double
    let volatility: Volatility
    let marketBid: Double
    let marketAsk: Double
    let order: IncomingOrder
    /// Change in fair value after the order arrives.
    let move: Double

    var fairAfter: Double { round2(fair + move) }
}

enum FillReason: String {
    case filled, priceTooHigh, priceTooLow, marketTookIt
}

struct MMRoundResult {
    let filled: Bool
    let reason: FillReason
    let bid: Double
    let ask: Double
    let price: Double
    let size: Int
    let inventoryBefore: Int
    let inventoryAfter: Int
    let spreadPnL: Double
    let inventoryPnL: Double
    let fairBefore: Double
    let fairAfter: Double
    let risk: Double
    let note: String

    var total: Double { spreadPnL + inventoryPnL }
}

struct MMReviewLine {
    let title: String
    let value: String
    let verdict: String
}

struct MMReview {
    let totalPnL: Double
    let fills: Int
    let rounds: Int
    let avgEdge: Double
    let maxInventory: Int
    let informedFills: Int
    /// 0…1 skill score fed into the Market Making mastery.
    let score: Double
    let headline: String
    let lines: [MMReviewLine]
}

/// A deliberately simplified, educational market-making model. It teaches
/// uncertainty + pricing + spread + inventory + decision making — it is not a trading engine.
enum MarketMakerEngine {

    static let startInventory = 14

    static func scenarios(seed: UInt64, rounds: Int = 6) -> [MMScenario] {
        var rng = SeededRNG(seed: seed &+ 0xA11CE)
        var out: [MMScenario] = []
        var fair = 102.40
        for i in 0..<rounds {
            if i == 0 {
                // The scenario from the product brief: fair 102.40, market 101.90 × 103.10, BUY +40 @ 102.80.
                let s = MMScenario(id: 0, asset: "QF-01", fair: 102.40, volatility: .high, marketBid: 101.90, marketAsk: 103.10,
                                   order: IncomingOrder(side: .buy, size: 40, limit: 102.80, informed: false), move: 0.15)
                out.append(s)
                fair = s.fairAfter
                continue
            }
            let vol = rng.pick(Volatility.allCases)
            let bidGap = 0.10 * Double(rng.int(3...7))
            let askGap = 0.10 * Double(rng.int(3...8))
            let side: Side = rng.chance(0.5) ? .buy : .sell
            let size = 10 * rng.int(1...6)
            let edge = 0.05 * Double(rng.int(4...19))
            let limit = round2(side == .buy ? fair + edge : fair - edge)
            let informed = rng.chance(0.4)
            var move = rng.gaussian() * vol.sigma * (informed ? 0.6 : 0.35)
            if informed {
                move = (side == .buy ? 1.0 : -1.0) * (abs(move) + vol.sigma * 0.5)
            }
            move = round2(move)
            let s = MMScenario(id: i, asset: "QF-01", fair: fair, volatility: vol,
                               marketBid: round2(fair - bidGap), marketAsk: round2(fair + askGap),
                               order: IncomingOrder(side: side, size: size, limit: limit, informed: informed), move: move)
            out.append(s)
            fair = s.fairAfter
        }
        return out
    }

    static func resolve(_ s: MMScenario, bid: Double, ask: Double, inventory: Int) -> MMRoundResult {
        let eps = 1e-9
        var filled = false
        var reason: FillReason = .filled
        var price = 0.0
        let o = s.order

        if o.side == .buy {
            if ask <= o.limit + eps {
                if ask <= s.marketAsk + eps { filled = true; price = ask } else { reason = .marketTookIt }
            } else { reason = .priceTooHigh }
        } else {
            if bid >= o.limit - eps {
                if bid >= s.marketBid - eps { filled = true; price = bid } else { reason = .marketTookIt }
            } else { reason = .priceTooLow }
        }

        var after = inventory
        var spread = 0.0
        var note: String
        if filled {
            if o.side == .buy {
                after = inventory - o.size
                spread = (price - s.fair) * Double(o.size)
                note = "SOLD \(o.size) @ \(Fmt.price(price))"
            } else {
                after = inventory + o.size
                spread = (s.fair - price) * Double(o.size)
                note = "BOUGHT \(o.size) @ \(Fmt.price(price))"
            }
        } else {
            switch reason {
            case .priceTooHigh: note = "NO FILL — your offer \(Fmt.price(ask)) is above the buyer's limit \(Fmt.price(o.limit))"
            case .priceTooLow: note = "NO FILL — your bid \(Fmt.price(bid)) is below the seller's limit \(Fmt.price(o.limit))"
            default:
                note = o.side == .buy
                    ? "NO FILL — the market's offer \(Fmt.price(s.marketAsk)) was cheaper than yours"
                    : "NO FILL — the market's bid \(Fmt.price(s.marketBid)) was higher than yours"
            }
        }
        let after2 = round2(s.fair + s.move)
        let invPnL = Double(after) * (after2 - s.fair)
        return MMRoundResult(filled: filled, reason: filled ? .filled : reason, bid: bid, ask: ask, price: price, size: filled ? o.size : 0,
                             inventoryBefore: inventory, inventoryAfter: after, spreadPnL: spread, inventoryPnL: invPnL,
                             fairBefore: s.fair, fairAfter: after2, risk: Double(abs(after)) * s.volatility.sigma, note: note)
    }

    static func review(_ results: [MMRoundResult], scenarios: [MMScenario]) -> MMReview {
        let total = results.reduce(0) { $0 + $1.total }
        let fillList = results.filter { $0.filled }
        let fills = fillList.count
        let sizeSum = fillList.reduce(0) { $0 + $1.size }
        let spreadSum = fillList.reduce(0.0) { $0 + $1.spreadPnL }
        let avgEdge = sizeSum == 0 ? 0 : spreadSum / Double(sizeSum)
        let maxInv = results.map { abs($0.inventoryAfter) }.max() ?? 0
        var informedFills = 0
        for (i, r) in results.enumerated() where r.filled && i < scenarios.count && scenarios[i].order.informed { informedFills += 1 }
        let rounds = max(results.count, 1)
        let flow = Double(fills) / Double(rounds)
        let pnlScore = clamp(0.5 + total / 80.0, 0, 1)
        let riskScore = 1 - clamp(Double(maxInv) / 100.0, 0, 1)
        let score = 0.5 * pnlScore + 0.3 * flow + 0.2 * riskScore

        let edgeVerdict = fills == 0 ? "No trades" : (avgEdge >= 0.15 ? "Solid" : (avgEdge >= 0.05 ? "Thin" : "Giving it away"))
        let flowVerdict = flow >= 0.5 ? "Competitive" : (flow >= 0.2 ? "Selective" : "Too wide")
        let riskVerdict = maxInv <= 40 ? "Controlled" : (maxInv <= 70 ? "Elevated" : "Heavy")
        let headline = total >= 15 ? "PROFITABLE DESK" : (total >= 0 ? "FLAT DESK" : "LOSING DESK")
        let lines = [
            MMReviewLine(title: "EDGE PER SHARE", value: (fills == 0 ? "—" : Fmt.signed(avgEdge, decimals: 2)), verdict: edgeVerdict),
            MMReviewLine(title: "FLOW WON", value: "\(fills) of \(results.count)", verdict: flowVerdict),
            MMReviewLine(title: "PEAK INVENTORY", value: "\(maxInv)", verdict: riskVerdict)
        ]
        return MMReview(totalPnL: total, fills: fills, rounds: results.count, avgEdge: avgEdge, maxInventory: maxInv,
                        informedFills: informedFills, score: score, headline: headline, lines: lines)
    }
}

// MARK: - EV Game

struct Gamble {
    let legs: [GambleLeg]
    var ev: Double { legs.reduce(0) { $0 + $1.probability * $1.payoff } }
}

enum GameChoice: String { case a, b }

struct EVRound: Identifiable {
    let id: Int
    let a: Gamble
    let b: Gamble
    var better: GameChoice { a.ev >= b.ev ? .a : .b }
}

enum EVGameEngine {

    static func rounds(seed: UInt64, count: Int = 6) -> [EVRound] {
        var rng = SeededRNG(seed: seed &+ 0xE7)
        var out: [EVRound] = []
        for i in 0..<count {
            if i == 0 {
                // Brief example: 50% +10 / 50% −4 versus 70% +7 / 30% −2.
                let a = Gamble(legs: [GambleLeg(probability: 0.5, payoff: 10), GambleLeg(probability: 0.5, payoff: -4)])
                let b = Gamble(legs: [GambleLeg(probability: 0.7, payoff: 7), GambleLeg(probability: 0.3, payoff: -2)])
                out.append(EVRound(id: 0, a: a, b: b))
                continue
            }
            var a = randomGamble(&rng)
            var b = randomGamble(&rng)
            var tries = 0
            while abs(a.ev - b.ev) < 0.5 && tries < 60 {
                a = randomGamble(&rng)
                b = randomGamble(&rng)
                tries += 1
            }
            out.append(EVRound(id: i, a: a, b: b))
        }
        return out
    }

    private static func randomGamble(_ rng: inout SeededRNG) -> Gamble {
        let p = 5 * rng.int(2...18)
        let w = rng.int(3...20)
        let l = rng.int(1...10)
        return Gamble(legs: [GambleLeg(probability: Double(p) / 100, payoff: Double(w)),
                             GambleLeg(probability: Double(100 - p) / 100, payoff: Double(-l))])
    }

    static func sample(_ g: Gamble, _ rng: inout SeededRNG) -> Double {
        let u = rng.double()
        var acc = 0.0
        for leg in g.legs {
            acc += leg.probability
            if u < acc { return leg.payoff }
        }
        return g.legs.last?.payoff ?? 0
    }

    /// Running average of repeated plays — converges to the expected value.
    static func runningAverage(_ g: Gamble, plays: Int, seed: UInt64) -> [Double] {
        var rng = SeededRNG(seed: seed)
        var total = 0.0
        var out: [Double] = []
        out.reserveCapacity(plays)
        for i in 1...max(plays, 1) {
            total += sample(g, &rng)
            out.append(total / Double(i))
        }
        return out
    }
}

// MARK: - Mock interview

enum InterviewEngine {
    static let totalSeconds = 120.0
    static let questionCount = 10

    static func makeSet(seed: UInt64) -> [QuantQuestion] {
        var rng = SeededRNG(seed: seed &+ 0x1D)
        func gen(_ kind: GeneratorKind, _ d: Int) -> QuantQuestion {
            QuestionGenerators.make(kind, difficulty: d, seed: rng.next() & 0x0FFF_FFFF)
        }
        let opener = gen(.mul, 1)
        let rest: [QuantQuestion] = [
            gen(.mul, 2), gen(.pct, 1), gen(.prob, 1), gen(.prob, 1),
            gen(.ev, 1), gen(.ev, 2), gen(.seq, 1), gen(.seq, 2), gen(.est, 1)
        ]
        return [opener] + rng.shuffled(rest)
    }

    static func skillOf(_ q: QuantQuestion) -> SkillKey { q.skills.first ?? .mentalMath }

    static func report(questions: [QuantQuestion], correct: [Bool], seconds: [Double], used: Double, now: Date = Date()) -> InterviewReport {
        var perSkill: [SkillKey: (n: Int, c: Int)] = [:]
        var speedSum = 0.0
        for (i, q) in questions.enumerated() {
            let ok = i < correct.count ? correct[i] : false
            let sec = i < seconds.count ? seconds[i] : q.targetSeconds * 2
            let key = skillOf(q)
            var cur = perSkill[key] ?? (0, 0)
            cur.n += 1
            if ok { cur.c += 1 }
            perSkill[key] = cur
            if ok { speedSum += ScoringEngine.speedScore(ratio: sec / max(q.targetSeconds, 1)) }
        }
        let total = questions.count
        let right = correct.filter { $0 }.count
        var bySkill: [String: Double] = [:]
        for (k, v) in perSkill { bySkill[k.rawValue] = v.n == 0 ? 0 : Double(v.c) / Double(v.n) }
        let ranked = perSkill.keys.sorted {
            let a = bySkill[$0.rawValue] ?? 0
            let b = bySkill[$1.rawValue] ?? 0
            return a == b ? $0.rawValue < $1.rawValue : a < b
        }
        let focus = ranked.prefix(2).map { $0.name }
        return InterviewReport(date: now, total: total, correct: right, accuracy: total == 0 ? 0 : Double(right) / Double(total),
                               speed: total == 0 ? 0 : speedSum / Double(total), secondsUsed: used, bySkill: bySkill, focus: Array(focus))
    }
}
