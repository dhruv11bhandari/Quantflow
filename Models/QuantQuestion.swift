import Foundation

enum InputSpec {
    case numeric(value: Double, kind: AnswerKind, tolerance: Tolerance)
    case choice(options: [String], correct: Int)
    case quote(QuoteSpec)
    /// Formula / trick cards: nothing to answer, steps are revealed one at a time.
    case read(steps: [String])
}

struct QuantQuestion: Identifiable {
    let id: String
    let type: QuestionType
    let topic: QuantTopic
    let difficulty: Int
    /// Small label above the prompt, e.g. "MENTAL MATH", "QUANT TRICK".
    let header: String
    let prompt: String
    let input: InputSpec
    /// Canonical answer for display ("2499", "5/36 ≈ 0.139").
    let answer: String
    let explanation: String
    let shortcut: String?
    let targetSeconds: Double
    let skills: [SkillKey]
    let visual: QuestionVisual

    var isReadOnly: Bool {
        if case .read = input { return true }
        return false
    }

    var isProbability: Bool {
        if case .numeric(_, let kind, _) = input, case .probability = kind { return true }
        return false
    }

    /// Expected numeric value when the question has one.
    var numericValue: Double? {
        if case .numeric(let v, _, _) = input { return v }
        return nil
    }
}

// MARK: - Factories (keep the curated bank compact and uniform)

extension QuantQuestion {
    static func defaultSkills(_ type: QuestionType, _ topic: QuantTopic) -> [SkillKey] {
        switch type {
        case .formula: return []
        case .brainteaser: return [.logic]
        default: return [topic.skill]
        }
    }

    static func num(_ id: String, _ type: QuestionType, _ topic: QuantTopic, d: Int, _ prompt: String, _ value: Double,
                    show: String? = nil, why: String, tip: String? = nil, t: Double,
                    tol: Tolerance = .exact, kind: AnswerKind = .number,
                    header: String? = nil, visual: QuestionVisual = .none) -> QuantQuestion {
        QuantQuestion(id: id, type: type, topic: topic, difficulty: d, header: header ?? type.title, prompt: prompt,
                      input: .numeric(value: value, kind: kind, tolerance: tol),
                      answer: show ?? Fmt.num(value), explanation: why, shortcut: tip, targetSeconds: t,
                      skills: defaultSkills(type, topic), visual: visual)
    }

    static func choice(_ id: String, _ type: QuestionType, _ topic: QuantTopic, d: Int, _ prompt: String,
                       _ options: [String], correct: Int, why: String, tip: String? = nil, t: Double,
                       header: String? = nil) -> QuantQuestion {
        QuantQuestion(id: id, type: type, topic: topic, difficulty: d, header: header ?? type.title, prompt: prompt,
                      input: .choice(options: options, correct: correct),
                      answer: options[correct], explanation: why, shortcut: tip, targetSeconds: t,
                      skills: defaultSkills(type, topic), visual: .none)
    }

    static func read(_ id: String, _ topic: QuantTopic, header: String, _ prompt: String, steps: [String],
                     why: String, tip: String? = nil) -> QuantQuestion {
        QuantQuestion(id: id, type: .formula, topic: topic, difficulty: 1, header: header, prompt: prompt,
                      input: .read(steps: steps), answer: "", explanation: why, shortcut: tip, targetSeconds: 10,
                      skills: [], visual: .none)
    }

    static func quote(_ id: String, d: Int, _ prompt: String, _ spec: QuoteSpec, why: String, tip: String? = nil,
                      t: Double) -> QuantQuestion {
        let answer = "\(Fmt.price(spec.bidMin))–\(Fmt.price(spec.bidMax)) × \(Fmt.price(spec.askMin))–\(Fmt.price(spec.askMax))"
        return QuantQuestion(id: id, type: .marketMaking, topic: .marketMaking, difficulty: d, header: "MARKET MAKING",
                             prompt: prompt, input: .quote(spec), answer: answer, explanation: why, shortcut: tip,
                             targetSeconds: t, skills: [.marketMaking], visual: .none)
    }
}
