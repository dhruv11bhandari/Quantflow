import Foundation

/// Local, seeded question generators. A generated question's ID is `g.<kind>.<difficulty>.<seed>`,
/// so the exact same question can be rebuilt from the ID alone (used by spaced review).
enum GeneratorKind: String, CaseIterable {
    case mul, pct, frac, prob, ev, est, seq
}

enum QuestionGenerators {

    static func id(_ kind: GeneratorKind, _ difficulty: Int, _ seed: UInt64) -> String {
        "g.\(kind.rawValue).\(difficulty).\(seed)"
    }

    static func parse(id: String) -> (kind: GeneratorKind, difficulty: Int, seed: UInt64)? {
        let parts = id.split(separator: ".").map(String.init)
        guard parts.count == 4, parts[0] == "g", let kind = GeneratorKind(rawValue: parts[1]),
              let d = Int(parts[2]), let seed = UInt64(parts[3]), (1...5).contains(d) else { return nil }
        return (kind, d, seed)
    }

    static func make(_ kind: GeneratorKind, difficulty: Int, seed: UInt64) -> QuantQuestion {
        let d = clamp(difficulty, 1, 5)
        switch kind {
        case .mul: return multiplication(d, seed)
        case .pct: return percentage(d, seed)
        case .frac: return fraction(d, seed)
        case .prob: return probability(d, seed)
        case .ev: return expectedValue(d, seed)
        case .est: return estimation(d, seed)
        case .seq: return sequence(d, seed)
        }
    }

    // MARK: Mental multiplication

    static func multiplication(_ d: Int, _ seed: UInt64) -> QuantQuestion {
        var rng = SeededRNG(seed: seed)
        let id = Self.id(.mul, d, seed)
        let times: [Double] = [5, 7, 9, 11, 14]
        let t = times[d - 1]
        let topic: QuantTopic = .arithmetic

        func make(_ prompt: String, _ answer: Int, why: String, tip: String) -> QuantQuestion {
            .num(id, .mentalMath, topic, d: d, prompt, Double(answer), why: why, tip: tip, t: t)
        }

        switch d {
        case 1:
            switch rng.int(0...2) {
            case 0:
                let n = rng.int(12...48)
                return make("\(n) × 11", n * 11, why: "\(n) × 10 + \(n) = \(n * 10) + \(n) = \(n * 11).", tip: "× 11 = × 10 + × 1")
            case 1:
                let n = 4 * rng.int(3...24)
                return make("\(n) × 25", n * 25, why: "\(n) × 100 ÷ 4 = \(n * 100) ÷ 4 = \(n * 25).", tip: "× 25 = × 100 ÷ 4")
            default:
                let n = rng.int(14...98)
                return make("\(n) × 5", n * 5, why: "\(n) × 10 ÷ 2 = \(n * 10) ÷ 2 = \(n * 5).", tip: "× 5 = × 10 ÷ 2")
            }
        case 2:
            switch rng.int(0...2) {
            case 0:
                let k = rng.int(2...9)
                let n = 10 * k + 5
                return make("\(n)²", n * n, why: "\(k) × \(k + 1) = \(k * (k + 1)); append 25 → \(n * n).",
                            tip: "(10k + 5)² = 100·k(k + 1) + 25")
            case 1:
                let n = rng.int(12...87)
                if rng.chance(0.5) {
                    return make("\(n) × 99", n * 99, why: "\(n) × 100 − \(n) = \(n * 100) − \(n) = \(n * 99).", tip: "× 99 = × 100 − × 1")
                }
                return make("\(n) × 9", n * 9, why: "\(n) × 10 − \(n) = \(n * 10) − \(n) = \(n * 9).", tip: "× 9 = × 10 − × 1")
            default:
                let n = 2 * rng.int(4...30)
                return make("\(n) × 15", n * 15, why: "\(n) × 10 + \(n) × 5 = \(n * 10) + \(n * 5) = \(n * 15).", tip: "× 15 = × 10 + half of that")
            }
        case 3:
            let a = rng.pick([20, 30, 40, 50, 60, 70, 80, 90, 100])
            let b = rng.int(1...4)
            return make("\(a - b) × \(a + b)", a * a - b * b,
                        why: "\(a)² − \(b)² = \(a * a) − \(b * b) = \(a * a - b * b).", tip: "(a − b)(a + b) = a² − b²")
        case 4:
            let x = rng.int(2...12)
            let y = rng.int(2...12)
            if rng.chance(0.5) {
                let ans = (100 - x) * (100 - y)
                return make("\(100 - x) × \(100 - y)", ans,
                            why: "100 × (100 − \(x) − \(y)) + \(x) × \(y) = \(100 * (100 - x - y)) + \(x * y) = \(ans).",
                            tip: "(100 − x)(100 − y) = 100(100 − x − y) + xy")
            }
            let ans = (100 + x) * (100 + y)
            return make("\(100 + x) × \(100 + y)", ans,
                        why: "100 × (100 + \(x) + \(y)) + \(x) × \(y) = \(100 * (100 + x + y)) + \(x * y) = \(ans).",
                        tip: "(100 + x)(100 + y) = 100(100 + x + y) + xy")
        default:
            let a = rng.int(13...29)
            let b = rng.int(13...29)
            let tens = (b / 10) * 10
            let ones = b % 10
            return make("\(a) × \(b)", a * b,
                        why: "\(a) × \(tens) + \(a) × \(ones) = \(a * tens) + \(a * ones) = \(a * b).", tip: "Split the second number into tens and ones")
        }
    }

    // MARK: Percentages

    static func percentage(_ d: Int, _ seed: UInt64) -> QuantQuestion {
        var rng = SeededRNG(seed: seed)
        let id = Self.id(.pct, d, seed)
        let times: [Double] = [6, 8, 10, 12, 14]
        let t = times[d - 1]

        func make(_ prompt: String, _ answer: Double, why: String, tip: String?) -> QuantQuestion {
            .num(id, .mentalMath, .percentages, d: d, prompt, answer, why: why, tip: tip, t: t, header: "PERCENTAGES")
        }

        switch d {
        case 1:
            let x = rng.pick([10, 20, 25, 50])
            let y = 20 * rng.int(2...20)
            let ans = x * y / 100
            let how: String
            switch x {
            case 10: how = "10% moves the decimal one place: \(y) → \(ans)."
            case 20: how = "10% of \(y) is \(y / 10); double it → \(ans)."
            case 25: how = "25% is a quarter: \(y) ÷ 4 = \(ans)."
            default: how = "50% is half: \(y) ÷ 2 = \(ans)."
            }
            return make("\(x)% of \(y)", Double(ans), why: how, tip: "10% → shift the decimal; 25% → ÷ 4; 50% → ÷ 2")
        case 2:
            let x = rng.pick([5, 15, 35, 45, 75, 85])
            let k = rng.int(2...25)
            let y = 20 * k
            let ans = x * k / 5
            return make("\(x)% of \(y)", Double(ans),
                        why: "\(x) × \(y) ÷ 100 = \(x * y) ÷ 100 = \(ans).", tip: "Build it from 10% and 5%")
        case 3:
            let k = rng.int(2...10)
            let a = 20 * k
            let p = rng.pick([10, 15, 20, 25, 30, 40, 50, 60])
            let up = rng.chance(0.5)
            let change = a * p / 100
            let b = up ? a + change : a - change
            let ans = up ? p : -p
            return make("A price moves from \(a) to \(b).\n\nPercent change?", Double(ans),
                        why: "Change = \(Fmt.signed(Double(b - a), decimals: 0)); \(Fmt.num(Double(abs(b - a)))) ÷ \(a) = \(p)%.",
                        tip: "Percent change = change ÷ starting value")
        case 4:
            let a = rng.pick([10, 20, 25, 50, 100])
            let b = rng.pick([10, 20, 25, 50])
            let net = Double((100 + a) * (100 - b)) / 100.0 - 100.0
            return make("A price rises \(a)%, then falls \(b)%.\n\nNet change in %?", net,
                        why: "\(Fmt.num(1 + Double(a) / 100, maxDecimals: 2)) × \(Fmt.num(1 - Double(b) / 100, maxDecimals: 2)) = \(Fmt.num(1 + net / 100, maxDecimals: 4)) → net \(Fmt.num(net, maxDecimals: 2))%. Percentages multiply, they don't cancel.",
                        tip: "Multiply the factors: (1 + a)(1 − b)")
        default:
            let p = rng.pick([10, 20, 25, 40, 50])
            let original = 100 * rng.int(1...12)
            let final = original * (100 - p) / 100
            let factor = Double(100 - p) / 100
            return make("After a \(p)% discount the price is ₹\(final).\n\nOriginal price?", Double(original),
                        why: "₹\(final) is \(100 - p)% of the original: \(final) ÷ \(Fmt.num(factor, maxDecimals: 2)) = \(original).",
                        tip: "Divide by the remaining fraction, don't add the discount back")
        }
    }

    // MARK: Fractions

    static func fraction(_ d: Int, _ seed: UInt64) -> QuantQuestion {
        var rng = SeededRNG(seed: seed)
        let id = Self.id(.frac, d, seed)
        let times: [Double] = [6, 9, 9, 11, 10]
        let t = times[d - 1]

        func exact(_ prompt: String, _ f: Frac, why: String, tip: String?) -> QuantQuestion {
            .num(id, .mentalMath, .fractions, d: d, prompt, f.value, show: f.display, why: why, tip: tip, t: t,
                 tol: .absolute(0.005), header: "FRACTIONS")
        }

        switch d {
        case 1:
            let den = rng.pick([4, 5, 8, 20, 25, 40])
            let n = rng.int(1...(den - 1))
            let v = Double(n) / Double(den)
            return .num(id, .mentalMath, .fractions, d: d, "\(n)/\(den) as a decimal?", v,
                        why: "\(n) ÷ \(den) = \(Fmt.num(v)).", tip: "1/8 = 0.125, 1/4 = 0.25, 1/5 = 0.2", t: t,
                        tol: .absolute(0.0005), header: "FRACTIONS")
        case 2:
            let pairs = [(2, 3), (3, 4), (4, 6), (2, 5), (3, 6), (4, 5), (6, 8), (3, 5)]
            let (d1, d2) = rng.pick(pairs)
            let n1 = rng.int(1...(d1 - 1))
            let n2 = rng.int(1...(d2 - 1))
            let f = Frac(n1, d1) + Frac(n2, d2)
            let lcm = d1 * d2 / Frac.gcd(d1, d2)
            return exact("\(n1)/\(d1) + \(n2)/\(d2)", f,
                         why: "Common denominator \(lcm): \(n1 * lcm / d1)/\(lcm) + \(n2 * lcm / d2)/\(lcm) = \(f.text).",
                         tip: "Use the least common denominator")
        case 3:
            let d1 = rng.pick([3, 4, 5, 6, 8, 9])
            let d2 = rng.pick([3, 4, 5, 6, 8, 9])
            let n1 = rng.int(1...(d1 - 1))
            let n2 = rng.int(1...(d2 - 1))
            let f = Frac(n1, d1) * Frac(n2, d2)
            return exact("\(n1)/\(d1) × \(n2)/\(d2)", f,
                         why: "Multiply across and simplify: \(n1 * n2)/\(d1 * d2) = \(f.text).", tip: "Cancel common factors before multiplying")
        case 4:
            let d1 = rng.pick([3, 4, 5, 6, 8])
            let d2 = rng.pick([3, 4, 5, 6, 8])
            let n1 = rng.int(1...(d1 - 1))
            let n2 = rng.int(1...(d2 - 1))
            let f = Frac(n1 * d2, d1 * n2)
            return exact("\(n1)/\(d1) ÷ \(n2)/\(d2)", f,
                         why: "Flip and multiply: \(n1)/\(d1) × \(d2)/\(n2) = \(f.text).", tip: "Dividing by a fraction = multiplying by its reciprocal")
        default:
            let den = rng.pick([4, 5, 8, 10])
            let n = rng.int(1...(den - 1))
            let amount = den * rng.int(10...60)
            let ans = amount / den * n
            return .num(id, .mentalMath, .fractions, d: d, "\(n)/\(den) of \(amount)", Double(ans),
                        why: "\(amount) ÷ \(den) = \(amount / den); × \(n) = \(ans).", tip: "Divide by the denominator first, then multiply", t: t,
                        header: "FRACTIONS")
        }
    }

    // MARK: Probability

    static func probability(_ d: Int, _ seed: UInt64) -> QuantQuestion {
        var rng = SeededRNG(seed: seed)
        let id = Self.id(.prob, d, seed)
        let times: [Double] = [14, 18, 22, 26, 28]
        let t = times[d - 1]

        func make(_ prompt: String, _ f: Frac, topic: QuantTopic = .probability, why: String, tip: String?) -> QuantQuestion {
            .num(id, .probability, topic, d: d, prompt, f.value, show: f.display, why: why, tip: tip, t: t,
                 tol: .absolute(0.005), kind: .probability)
        }

        switch d {
        case 1:
            if rng.chance(0.6) {
                let s = rng.pick([3, 4, 5, 6, 8, 9, 10, 11])
                let ways = 6 - abs(7 - s)
                return make("Two fair dice are rolled.\n\nWhat is the probability that their sum is \(s)?", Frac(ways, 36),
                            why: "\(ways) of the 36 equally likely outcomes sum to \(s) → \(Frac(ways, 36).text).",
                            tip: "Ways to make a sum s: 6 − |7 − s|")
            }
            let n = rng.int(2...4)
            let total = 1 << n
            return make("A fair coin is flipped \(n) times.\n\nProbability of at least one head?", Frac(total - 1, total),
                        why: "Complement: 1 − P(all tails) = 1 − 1/\(total) = \(total - 1)/\(total).",
                        tip: "\"At least one\" → 1 − P(none)")
        case 2:
            let n = rng.int(4...6)
            let k = rng.int(1...(n - 1))
            let total = 1 << n
            let ways = choose(n, k)
            return make("A fair coin is flipped \(n) times.\n\nProbability of exactly \(k) heads?", Frac(ways, total),
                        why: "C(\(n),\(k)) = \(ways) favourable sequences out of 2^\(n) = \(total) → \(Frac(ways, total).text).",
                        tip: "P(k heads) = C(n,k) / 2ⁿ")
        case 3:
            let r = rng.int(3...6)
            let b = rng.int(2...5)
            let n = r + b
            if rng.chance(0.5) {
                let f = Frac(r * (r - 1), n * (n - 1))
                return make("A bag holds \(r) red and \(b) blue balls. Two are drawn without replacement.\n\nP(both red)?", f,
                            why: "(\(r)/\(n)) × (\(r - 1)/\(n - 1)) = \(f.text).", tip: "Without replacement: the second draw sees one fewer ball")
            }
            let f = Frac(2 * r * b, n * (n - 1))
            return make("A bag holds \(r) red and \(b) blue balls. Two are drawn without replacement.\n\nP(one of each colour)?", f,
                        why: "Two orders (RB or BR): 2 × (\(r)/\(n)) × (\(b)/\(n - 1)) = \(f.text).", tip: "Add both orders: RB and BR")
        case 4:
            let s = rng.pick([7, 8, 9, 10])
            var pairs: [(Int, Int)] = []
            for a in 1...6 { for b in 1...6 where a + b == s { pairs.append((a, b)) } }
            let face = rng.pick(pairs).0
            let hits = pairs.filter { $0.0 == face || $0.1 == face }.count
            let f = Frac(hits, pairs.count)
            return make("Two fair dice are rolled and their sum is \(s).\n\nGiven that, probability that at least one die shows \(face)?", f,
                        topic: .conditionalProbability,
                        why: "Sum \(s) has \(pairs.count) outcomes; \(hits) contain a \(face) → \(f.text).",
                        tip: "P(A|B) = P(A∩B) / P(B) — shrink the sample space to B")
        default:
            switch rng.int(0...3) {
            case 0:
                let n = rng.int(3...5)
                let total = Int(pow(6.0, Double(n)))
                let none = Int(pow(5.0, Double(n)))
                let f = Frac(total - none, total)
                return make("A fair die is rolled \(n) times.\n\nProbability of at least one six?", f,
                            why: "1 − (5/6)^\(n) = 1 − \(none)/\(total) = \(f.text).", tip: "\"At least one\" → 1 − P(none)")
            case 1:
                let k = rng.int(1...2)
                let ways = choose(4, k) * Int(pow(5.0, Double(4 - k)))
                let f = Frac(ways, 1296)
                return make("A fair die is rolled 4 times.\n\nProbability of exactly \(k) six\(k == 1 ? "" : "es")?", f,
                            why: "C(4,\(k)) × (1/6)^\(k) × (5/6)^\(4 - k) = \(ways)/1,296 = \(f.text).", tip: "Binomial: C(n,k) pᵏ (1 − p)ⁿ⁻ᵏ")
            case 2:
                let s = rng.pick([9, 10, 11, 12])
                var ways = 0
                for a in 1...6 { for b in 1...6 { for c in 1...6 where a + b + c == s { ways += 1 } } }
                let f = Frac(ways, 216)
                return make("Three fair dice are rolled.\n\nProbability that the sum is \(s)?", f,
                            why: "\(ways) of the 216 equally likely outcomes sum to \(s) → \(f.text).", tip: "Count the ordered triples that reach the sum")
            default:
                let n = rng.pick([5, 6])
                let k = n - rng.int(1...2)
                var favourable = 0
                for j in k...n { favourable += choose(n, j) }
                let total = 1 << n
                let f = Frac(favourable, total)
                return make("A fair coin is flipped \(n) times.\n\nProbability of at least \(k) heads?", f,
                            why: "Add C(\(n),j) for j = \(k)…\(n): \(favourable) of 2^\(n) = \(total) sequences → \(f.text).", tip: "Sum the binomial terms from k up to n")
            }
        }
    }

    // MARK: Expected value

    static func expectedValue(_ d: Int, _ seed: UInt64) -> QuantQuestion {
        var rng = SeededRNG(seed: seed)
        let id = Self.id(.ev, d, seed)
        let times: [Double] = [12, 16, 20, 22, 26]
        let t = times[d - 1]

        func legText(_ p: Int, _ x: Int) -> String {
            "\(p)% chance → \(Fmt.signedMoney(Double(x)))"
        }

        switch d {
        case 1, 2:
            let p = d == 1 ? 10 * rng.int(1...9) : 5 * rng.int(1...19)
            let w = rng.int(4...30)
            let l = rng.int(1...12)
            let ev = Double(p * w - (100 - p) * l) / 100.0
            let a = Double(p * w) / 100.0
            let b = Double((100 - p) * l) / 100.0
            let legs = [GambleLeg(probability: Double(p) / 100, payoff: Double(w)),
                        GambleLeg(probability: Double(100 - p) / 100, payoff: Double(-l))]
            return .num(id, .expectedValue, .expectedValue, d: d,
                        "\(legText(p, w))\n\(legText(100 - p, -l))\n\nExpected value?", ev,
                        show: Fmt.num(ev), why: "\(Fmt.num(a, maxDecimals: 2)) − \(Fmt.num(b, maxDecimals: 2)) = \(Fmt.num(ev)).",
                        tip: "EV = Σ probability × payoff", t: t, tol: .absolute(0.01), visual: .gamble(legs))
        case 3:
            let split = rng.pick([(20, 30, 50), (10, 40, 50), (25, 25, 50), (30, 30, 40), (10, 20, 70)])
            let x1 = 5 * rng.int(6...16)
            let x2 = 5 * rng.int(1...5)
            let x3 = -5 * rng.int(1...5)
            let ev = Double(split.0 * x1 + split.1 * x2 + split.2 * x3) / 100.0
            let legs = [GambleLeg(probability: Double(split.0) / 100, payoff: Double(x1)),
                        GambleLeg(probability: Double(split.1) / 100, payoff: Double(x2)),
                        GambleLeg(probability: Double(split.2) / 100, payoff: Double(x3))]
            let terms = legs.map { Fmt.num($0.probability * $0.payoff, maxDecimals: 2) }
            return .num(id, .expectedValue, .expectedValue, d: d,
                        "\(legText(split.0, x1))\n\(legText(split.1, x2))\n\(legText(split.2, x3))\n\nExpected value?", ev,
                        show: Fmt.num(ev), why: "\(terms[0]) + \(terms[1]) + (\(terms[2])) = \(Fmt.num(ev)).",
                        tip: "Add one probability × payoff term per outcome", t: t, tol: .absolute(0.01), visual: .gamble(legs))
        case 4:
            let m = rng.int(1...3)
            let c = rng.int(2...6)
            let ev = Double(2 * m) - Double(c) / 2.0
            return .num(id, .expectedValue, .expectedValue, d: d,
                        "Roll a fair die.\nEven → win ₹\(m) × the face.\nOdd → lose ₹\(c).\n\nExpected value?", ev,
                        show: Fmt.num(ev),
                        why: "Even faces average 4 → half the time win ₹\(m * 4); odd half the time lose ₹\(c): \(Fmt.num(Double(m * 4) / 2)) − \(Fmt.num(Double(c) / 2)) = \(Fmt.num(ev)).",
                        tip: "Split by outcome class, weight by probability", t: t, tol: .absolute(0.01))
        default:
            let k = rng.int(3...5)
            let m = rng.int(2...4)
            let cost = rng.int(5...12)
            var sum = 0
            for f in k...6 { sum += f }
            let f = Frac(m * sum - 6 * cost, 6)
            return .num(id, .expectedValue, .expectedValue, d: d,
                        "Pay ₹\(cost) to play.\nRoll a fair die; if the face is \(k) or more, win ₹\(m) × the face.\n\nNet expected value?", f.value,
                        show: f.display,
                        why: "Payoff averages \(m) × (\((k...6).map(String.init).joined(separator: "+")))/6 = \(Frac(m * sum, 6).text); minus the ₹\(cost) fee → \(f.text).",
                        tip: "Net EV = expected payoff − cost", t: t, tol: .absolute(0.01))
        }
    }

    // MARK: Estimation

    static func estimation(_ d: Int, _ seed: UInt64) -> QuantQuestion {
        var rng = SeededRNG(seed: seed)
        let id = Self.id(.est, d, seed)
        let times: [Double] = [10, 12, 12, 14, 16]
        let t = times[d - 1]
        let tols: [Double] = [0.05, 0.04, 0.04, 0.03, 0.03]
        let tol = tols[d - 1]

        func make(_ prompt: String, _ value: Double, show: String, why: String, tip: String?) -> QuantQuestion {
            .num(id, .estimation, .estimation, d: d, prompt, value, show: show, why: why, tip: tip, t: t, tol: .relative(tol))
        }

        switch d {
        case 1:
            let r = rng.int(2...9)
            var off = rng.int(-4...4)
            if off == 0 { off = 3 }
            let s = rng.int(3...9)
            var off2 = rng.int(-3...3)
            if off2 == 0 { off2 = 2 }
            let a = 100 * r + off
            let b = 10 * s + off2
            let exact = a * b
            return make("\(a) × \(b) ≈ ?", Double(exact), show: Fmt.grouped(exact),
                        why: "Round to \(100 * r) × \(10 * s) = \(Fmt.grouped(1000 * r * s)); exact is \(Fmt.grouped(exact)).",
                        tip: "Round both factors, multiply, sanity-check the size")
        case 2:
            var n = rng.int(1500...9000)
            if let root = Optional(Int(Double(n).squareRoot())), root * root == n { n += 7 }
            let v = Double(n).squareRoot()
            let lo = Int(v)
            return make("√\(Fmt.grouped(n)) ≈ ?", v, show: Fmt.num(v, maxDecimals: 1),
                        why: "√\(Fmt.grouped(n)) lies between \(lo)² = \(lo * lo) and \(lo + 1)² = \((lo + 1) * (lo + 1)) → about \(Fmt.num(v, maxDecimals: 1)).",
                        tip: "Bracket between two perfect squares, then interpolate")
        case 3:
            let k = rng.int(17...27)
            let v = Int(pow(2.0, Double(k)))
            return make("2^\(k) ≈ ?", Double(v), show: Fmt.grouped(v),
                        why: "2¹⁰ ≈ 1,000, so 2^\(k) ≈ 2^\(k - 10) × 1,000; exactly \(Fmt.grouped(v)).",
                        tip: "2¹⁰ ≈ 10³ (really 1,024)")
        case 4:
            let x = rng.pick([2.5, 7.5, 12.5, 17.5, 6.5, 8.5])
            let y = 40 * rng.int(20...90)
            let v = x * Double(y) / 100.0
            return make("\(Fmt.num(x, maxDecimals: 1))% of \(Fmt.grouped(y)) ≈ ?", v, show: Fmt.num(v, maxDecimals: 1),
                        why: "10% of \(Fmt.grouped(y)) is \(Fmt.num(Double(y) / 10)); scale to \(Fmt.num(x, maxDecimals: 1))% → \(Fmt.num(v, maxDecimals: 1)).",
                        tip: "Anchor on 10% and 1%, then adjust")
        default:
            let r = rng.pick([6, 7, 8, 9, 10, 12])
            let n = rng.int(5...12)
            let v = 1000.0 * pow(1.0 + Double(r) / 100.0, Double(n))
            let rounded = Int(v.rounded())
            return make("₹1,000 grows \(r)% a year for \(n) years ≈ ?", v, show: "₹" + Fmt.grouped(rounded),
                        why: "1.\(String(format: "%02d", r))^\(n) ≈ \(Fmt.num(pow(1.0 + Double(r) / 100.0, Double(n)), maxDecimals: 3)) → about ₹\(Fmt.grouped(rounded)).",
                        tip: "Rule of 72: money doubles in about 72 ÷ r years")
        }
    }

    // MARK: Sequences

    static func sequence(_ d: Int, _ seed: UInt64) -> QuantQuestion {
        var rng = SeededRNG(seed: seed)
        let id = Self.id(.seq, d, seed)
        let times: [Double] = [8, 10, 14, 16, 20]
        let t = times[d - 1]

        func make(_ terms: [Int], _ next: Int, why: String, tip: String?) -> QuantQuestion {
            let shown = terms.map(String.init).joined(separator: ", ")
            return .num(id, .brainteaser, .logic, d: d, "\(shown), ?", Double(next), why: why, tip: tip, t: t, header: "PATTERN LOGIC")
        }

        switch d {
        case 1:
            let a = rng.int(2...20)
            let step = rng.int(2...9)
            let terms = (0..<5).map { a + $0 * step }
            return make(terms, a + 5 * step, why: "Each term adds \(step) → \(terms[4]) + \(step) = \(a + 5 * step).", tip: "Check the difference between neighbours")
        case 2:
            let a = rng.int(1...5)
            let r = rng.pick([2, 3])
            var terms: [Int] = []
            var cur = a
            for _ in 0..<5 { terms.append(cur); cur *= r }
            return make(terms, cur, why: "Each term is × \(r) → \(terms[4]) × \(r) = \(cur).", tip: "Check the ratio between neighbours")
        case 3:
            let kind = rng.int(0...6)
            switch kind {
            case 0:
                let terms = (1...5).map { $0 * $0 }
                return make(terms, 36, why: "Perfect squares: 1², 2², … → next is 6² = 36.", tip: "Squares, cubes, triangular numbers — check the classics")
            case 1:
                let terms = (1...4).map { $0 * $0 * $0 }
                return make(terms, 125, why: "Perfect cubes: 1³, 2³, … → next is 5³ = 125.", tip: "Squares, cubes, triangular numbers — check the classics")
            case 2:
                let terms = (1...5).map { $0 * ($0 + 1) / 2 }
                return make(terms, 21, why: "Triangular numbers: add 2, 3, 4, 5… → next adds 6: 15 + 6 = 21.", tip: "Differences that grow by 1 → triangular")
            case 3:
                let terms = (1...5).map { $0 * ($0 + 1) }
                return make(terms, 42, why: "n(n + 1): 1·2, 2·3, … → next is 6·7 = 42.", tip: "Differences 4, 6, 8, 10 → n(n + 1)")
            case 4:
                return make([2, 3, 5, 7, 11], 13, why: "The primes in order → the next prime after 11 is 13.", tip: "Irregular gaps that never share a factor → primes")
            case 5:
                return make([1, 3, 7, 15, 31], 63, why: "Each term is 2ⁿ − 1 (or double the last, plus 1) → 31 × 2 + 1 = 63.", tip: "Differences double: 2, 4, 8, 16 → 2ⁿ − 1")
            default:
                let c = rng.int(1...5)
                let terms = (1...5).map { $0 * $0 + c }
                let next = 36 + c
                return make(terms, next, why: "Squares plus \(c): n² + \(c) → 6² + \(c) = \(next).", tip: "Subtract the nearest squares to expose the constant")
            }
        case 4:
            let a = rng.int(1...6)
            let b = rng.int(2...7)
            var terms = [a, b]
            for i in 2..<6 { terms.append(terms[i - 1] + terms[i - 2]) }
            let next = terms[5] + terms[4]
            return make(Array(terms.prefix(6)), next, why: "Each term is the sum of the previous two → \(terms[5]) + \(terms[4]) = \(next).", tip: "Fibonacci-style: a + b = c")
        default:
            let s = rng.int(1...6)
            let add = rng.int(2...5)
            let mul = rng.int(2...3)
            var terms = [s]
            for i in 1..<6 { terms.append(i % 2 == 1 ? terms[i - 1] + add : terms[i - 1] * mul) }
            let next = terms[5] * mul
            return make(terms, next, why: "Operations alternate: + \(add), × \(mul), + \(add), × \(mul)… → the next step is × \(mul): \(terms[5]) × \(mul) = \(next).",
                        tip: "When differences look random, look for alternating operations")
        }
    }
}
