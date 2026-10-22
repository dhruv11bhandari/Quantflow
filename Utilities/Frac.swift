import Foundation

/// Exact rational number used by the probability generators so answers are never rounded until display.
struct Frac: Equatable {
    let n: Int
    let d: Int

    init(_ n: Int, _ d: Int) {
        let denominator = d == 0 ? 1 : d
        var g = Frac.gcd(abs(n), abs(denominator))
        if g == 0 { g = 1 }
        let sign = denominator < 0 ? -1 : 1
        self.n = sign * n / g
        self.d = sign * denominator / g
    }

    static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }

    var value: Double { Double(n) / Double(d) }

    var text: String {
        let num = n < 0 ? Fmt.minus + String(-n) : String(n)
        return d == 1 ? num : "\(num)/\(d)"
    }

    /// "5/36 ≈ 0.139"
    var display: String {
        d == 1 ? text : "\(text) ≈ \(Fmt.num(value, maxDecimals: 3))"
    }

    static func + (a: Frac, b: Frac) -> Frac { Frac(a.n * b.d + b.n * a.d, a.d * b.d) }
    static func * (a: Frac, b: Frac) -> Frac { Frac(a.n * b.n, a.d * b.d) }
}

/// n choose k as an exact Int (small inputs only).
func choose(_ n: Int, _ k: Int) -> Int {
    if k < 0 || k > n { return 0 }
    var result = 1
    let kk = min(k, n - k)
    if kk == 0 { return 1 }
    for i in 1...kk {
        result = result * (n - kk + i) / i
    }
    return result
}
