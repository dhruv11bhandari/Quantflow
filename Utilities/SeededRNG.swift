import Foundation

/// Deterministic SplitMix64 generator. The same seed always produces the same
/// sequence on every device, which lets generated questions be re-created from
/// their ID alone (used by the spaced-review queue).
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform integer in a closed range (modulo method keeps results stable across Swift versions).
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    mutating func double() -> Double { Double(next() >> 11) / 9_007_199_254_740_992.0 }

    mutating func chance(_ p: Double) -> Bool { double() < p }

    mutating func pick<T>(_ items: [T]) -> T { items[int(0...(items.count - 1))] }

    mutating func shuffled<T>(_ items: [T]) -> [T] {
        var a = items
        if a.count < 2 { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            let j = int(0...i)
            if i != j { a.swapAt(i, j) }
        }
        return a
    }

    /// Standard normal sample (Box–Muller).
    mutating func gaussian() -> Double {
        let u1 = max(double(), 1e-12)
        let u2 = double()
        return (-2.0 * log(u1)).squareRoot() * cos(2.0 * Double.pi * u2)
    }
}

/// Stable string hash (FNV-1a). Swift's `hashValue` is randomised per launch, so it must not be used for seeds.
func stableHash(_ s: String) -> UInt64 {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for b in s.utf8 {
        h ^= UInt64(b)
        h = h &* 0x0000_0100_0000_01B3
    }
    return h
}
