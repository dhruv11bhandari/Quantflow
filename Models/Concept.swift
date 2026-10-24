import Foundation

enum LearnCategory: String, CaseIterable, Identifiable {
    case mentalMath, probability, expectedValue, combinatorics, statistics, markets, options, strategies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mentalMath: return "MENTAL MATH"
        case .probability: return "PROBABILITY"
        case .expectedValue: return "EXPECTED VALUE"
        case .combinatorics: return "COMBINATORICS"
        case .statistics: return "STATISTICS"
        case .markets: return "MARKETS"
        case .options: return "OPTIONS"
        case .strategies: return "QUANT STRATEGIES"
        }
    }

    var symbol: String {
        switch self {
        case .mentalMath: return "multiply"
        case .probability: return "dice"
        case .expectedValue: return "scalemass"
        case .combinatorics: return "square.grid.3x3"
        case .statistics: return "chart.bar"
        case .markets: return "chart.bar.xaxis"
        case .options: return "arrow.up.right"
        case .strategies: return "wand.and.stars"
        }
    }
}

/// One Learn-library entry: FORMULA → INTUITION → EXAMPLE → CHALLENGE.
struct Concept: Identifiable {
    let id: String
    let category: LearnCategory
    let title: String
    let formulaLead: String
    let formulaTop: String
    /// When set, the formula is drawn as a fraction: top over bottom.
    let formulaBottom: String?
    let intuition: String
    let example: String
    let challenge: QuantQuestion
}


extension Concept {
    /// One-line version of the formula, for list rows and accessibility.
    var formulaLine: String {
        if let b = formulaBottom { return "\(formulaLead) \(formulaTop) / \(b)" }
        return formulaLead.isEmpty ? formulaTop : "\(formulaLead) \(formulaTop)"
    }
}
