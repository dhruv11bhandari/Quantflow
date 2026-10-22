import Foundation

/// Deterministic answer checking. No network, no model — plain arithmetic with explicit tolerances.
enum AnswerValidator {

    struct Parsed {
        let value: Double
        let hadPercent: Bool
    }

    /// Accepts "2499", "−4", "0.375", "5/36", "13.9%", "1,200", "₹20", "~100".
    static func parse(_ raw: String) -> Parsed? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for (a, b) in [("\u{2212}", "-"), ("\u{2013}", "-"), (",", ""), ("₹", ""), ("$", ""), ("~", ""), ("≈", ""), (" ", "")] {
            s = s.replacingOccurrences(of: a, with: b)
        }
        var percent = false
        if s.hasSuffix("%") {
            percent = true
            s.removeLast()
        }
        if s.isEmpty { return nil }

        if let slash = s.firstIndex(of: "/") {
            let n = String(s[s.startIndex..<slash])
            let d = String(s[s.index(after: slash)...])
            guard let nv = Double(n), let dv = Double(d), dv != 0, nv.isFinite, dv.isFinite else { return nil }
            return Parsed(value: nv / dv, hadPercent: percent)
        }
        guard let v = Double(s), v.isFinite else { return nil }
        return Parsed(value: v, hadPercent: percent)
    }

    static func within(_ candidate: Double, expected: Double, tolerance: Tolerance) -> Bool {
        let diff = abs(candidate - expected)
        switch tolerance {
        case .exact:
            return diff <= 1e-9 * max(1, abs(expected))
        case .absolute(let t):
            return diff <= t + 1e-12
        case .relative(let r):
            return diff <= r * max(abs(expected), 1e-9) + 1e-12
        }
    }

    static func isCorrect(_ raw: String, expected: Double, kind: AnswerKind, tolerance: Tolerance) -> Bool {
        guard let p = parse(raw) else { return false }
        var candidates = [p.value]
        if case .probability = kind {
            if p.hadPercent { candidates = [p.value / 100] }
            else if abs(p.value) > 1 { candidates.append(p.value / 100) }
        }
        return candidates.contains { within($0, expected: expected, tolerance: tolerance) }
    }

    /// Relative distance between the typed answer and the expected one (nil when it can't be parsed).
    static func relativeError(_ raw: String, expected: Double, kind: AnswerKind) -> Double? {
        guard let p = parse(raw) else { return nil }
        var v = p.value
        if case .probability = kind, p.hadPercent || abs(p.value) > 1 { v = p.value / 100 }
        return abs(v - expected) / max(abs(expected), 1e-9)
    }
}

enum AnswerEvaluator {
    static func evaluate(_ q: QuantQuestion, _ a: UserAnswer) -> EvaluationResult {
        if case .skipped = a { return EvaluationResult(correct: false, skipped: true, relativeError: nil, note: "Skipped") }

        switch q.input {
        case .read:
            return EvaluationResult(correct: true, skipped: false, relativeError: nil, note: nil)

        case .numeric(let value, let kind, let tol):
            guard case .text(let raw) = a else {
                return EvaluationResult(correct: false, skipped: false, relativeError: nil, note: nil)
            }
            let ok = AnswerValidator.isCorrect(raw, expected: value, kind: kind, tolerance: tol)
            let err = AnswerValidator.relativeError(raw, expected: value, kind: kind)
            var note: String? = nil
            if case .relative(let r) = tol, ok, let e = err, e > 1e-9 {
                note = "Within \(Fmt.num(r * 100, maxDecimals: 1))% — accepted"
            }
            return EvaluationResult(correct: ok, skipped: false, relativeError: err, note: note)

        case .choice(_, let correct):
            guard case .choice(let picked) = a else {
                return EvaluationResult(correct: false, skipped: false, relativeError: nil, note: nil)
            }
            return EvaluationResult(correct: picked == correct, skipped: false, relativeError: nil, note: nil)

        case .quote(let spec):
            guard case .quote(let bid, let ask) = a else {
                return EvaluationResult(correct: false, skipped: false, relativeError: nil, note: nil)
            }
            let ok = spec.accepts(bid: bid, ask: ask)
            return EvaluationResult(correct: ok, skipped: false, relativeError: nil,
                                    note: "Your quote \(Fmt.price(bid)) × \(Fmt.price(ask))")
        }
    }
}
