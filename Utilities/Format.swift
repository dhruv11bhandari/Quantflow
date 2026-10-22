import Foundation

/// Number and text formatting used across the app. Uses a true minus sign (U+2212) for display.
enum Fmt {
    static let minus = "\u{2212}"

    /// Compact number: trims trailing zeros, "2499", "0.375", "−4".
    static func num(_ v: Double, maxDecimals: Int = 3) -> String {
        if abs(v - v.rounded()) < 1e-9 && abs(v) < 1e15 {
            let i = Int(v.rounded())
            return i < 0 ? minus + String(-i) : String(i)
        }
        var s = String(format: "%.\(maxDecimals)f", abs(v))
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        if s.isEmpty || s == "0" { return "0" }
        return v < 0 ? minus + s : s
    }

    /// "+12.0" / "−5.0" / "0.0"
    static func signed(_ v: Double, decimals: Int = 1) -> String {
        let s = String(format: "%.\(decimals)f", abs(v))
        let isZero = (Double(s) ?? 0) == 0
        if isZero { return s }
        return v > 0 ? "+" + s : minus + s
    }

    /// "₹20" / "−₹5"
    static func money(_ v: Double, decimals: Int = 0) -> String {
        let s = String(format: "%.\(decimals)f", abs(v))
        let isZero = (Double(s) ?? 0) == 0
        return (v < 0 && !isZero) ? minus + "₹" + s : "₹" + s
    }

    /// "+₹20" / "−₹5"
    static func signedMoney(_ v: Double, decimals: Int = 0) -> String {
        let s = String(format: "%.\(decimals)f", abs(v))
        let isZero = (Double(s) ?? 0) == 0
        if isZero { return "₹" + s }
        return v > 0 ? "+₹" + s : minus + "₹" + s
    }

    static func price(_ v: Double) -> String { String(format: "%.2f", v) }

    /// "02.8 sec"
    static func seconds(_ s: Double) -> String { String(format: "%04.1f", max(0, s)) + " sec" }

    static func clock(_ s: Double) -> String {
        let t = Int(max(0, s).rounded(.up))
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    /// 2481 → "2,481"
    static func grouped(_ n: Int) -> String {
        let digits = String(abs(n))
        var out = ""
        for (i, ch) in digits.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        let body = String(out.reversed())
        return n < 0 ? minus + body : body
    }

    static func percent(_ fraction: Double, decimals: Int = 0) -> String {
        String(format: "%.\(decimals)f%%", fraction * 100)
    }
}

func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(max(v, lo), hi) }

/// Turns math notation into words for VoiceOver ("49 × 51" → "49 times 51").
enum Spoken {
    static func math(_ s: String) -> String {
        var t = s
        let map: [(String, String)] = [
            ("×", " times "), ("÷", " divided by "), ("−", " minus "), ("²", " squared"), ("³", " cubed"),
            ("≈", " approximately "), ("√", "square root of "), ("₹", " rupees "), ("→", " gives "),
            ("%", " percent"), ("^", " to the power "), ("\n", ". ")
        ]
        for (a, b) in map { t = t.replacingOccurrences(of: a, with: b) }
        return t
    }
}
