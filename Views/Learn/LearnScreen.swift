import SwiftUI

/// LEARN: an interactive Probability Field plus a library of formula → intuition → example → challenge.
struct LearnScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var p: Double = 0.25
    @State private var category: LearnCategory? = nil
    @State private var selected: Concept? = nil

    private let presets: [Double] = [0.1, 0.25, 0.5, 0.75]

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LEARN").qfLabel(Theme.accent)
                        Text("Formula. Intuition. Example. Challenge.").qf(28, .bold, relativeTo: .title).foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 14)
                    lab
                    chips
                    list
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .qfColumn()
        }
        .fullScreenCover(item: $selected) { c in
            ConceptView(concept: c, onClose: { selected = nil })
        }
    }

    // MARK: Probability Field lab

    private var lab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PROBABILITY FIELD").qfLabel(Theme.accent)
                Spacer()
                Text("P = \(Fmt.num(p, maxDecimals: 2))")
                    .qf(17, .bold, design: .monospaced, relativeTo: .headline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
            }
            ProbabilityField(probability: p, height: 150)
            Slider(value: $p, in: 0...1, step: 0.01)
                .tint(Theme.accent)
                .accessibilityLabel("Probability")
                .accessibilityValue("\(Int((p * 100).rounded())) percent")
            HStack(spacing: 8) {
                ForEach(0..<presets.count, id: \.self) { i in
                    presetChip(presets[i])
                }
            }
            Text("Each dot is one simulated outcome. Drag the slider: the share that lands in the HIT bin is the probability.")
                .qf(13, .regular, relativeTo: .footnote).foregroundStyle(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .qfCard(padding: 16, radius: 24)
    }

    private func presetChip(_ value: Double) -> some View {
        let active = abs(p - value) < 0.005
        return Button(action: {
            Haptics.select()
            withAnimation(Motion.spring) { p = value }
        }) {
            Text(Fmt.num(value, maxDecimals: 2))
                .qf(13, .semibold, design: .monospaced, relativeTo: .footnote)
                .foregroundStyle(active ? Theme.bg : Theme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background { Capsule().fill(active ? Theme.accent : Theme.surfaceHigh) }
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Set probability to \(Fmt.num(value, maxDecimals: 2))")
    }

    // MARK: Library

    private func chip(_ title: String, _ value: LearnCategory?) -> some View {
        let active = category == value
        let traits: AccessibilityTraits = active ? [.isButton, .isSelected] : [.isButton]
        return Button(action: {
            Haptics.select()
            withAnimation(Motion.smooth) { category = value }
        }) {
            Text(title)
                .qf(12, .semibold, design: .monospaced, relativeTo: .caption)
                .tracking(0.8)
                .foregroundStyle(active ? Theme.bg : Theme.textDim)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background { Capsule().fill(active ? Theme.accent : Theme.surface) }
                .overlay { Capsule().stroke(active ? Color.clear : Theme.line, lineWidth: 1) }
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(traits)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("ALL", nil)
                ForEach(LearnCategory.allCases) { c in
                    chip(c.title, c)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(LearnCategory.allCases) { cat in
                if category == nil || category == cat {
                    section(cat)
                }
            }
        }
    }

    private func section(_ cat: LearnCategory) -> some View {
        let items = LearnContent.concepts.filter { $0.category == cat }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: cat.symbol).qf(13, .semibold).foregroundStyle(Theme.accent)
                Text(cat.title).qfLabel(Theme.text)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ForEach(items) { c in
                row(c)
            }
        }
    }

    private func row(_ c: Concept) -> some View {
        let learned = model.save.learned.contains("concept." + c.id)
        return Button(action: {
            Haptics.tap()
            selected = c
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.title).qf(17, .semibold, relativeTo: .headline).foregroundStyle(Theme.text)
                    Text(c.formulaLine)
                        .qf(13, .regular, design: .monospaced, relativeTo: .footnote)
                        .foregroundStyle(Theme.textDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                if learned {
                    Image(systemName: "checkmark.circle.fill").qf(18, .semibold).foregroundStyle(Theme.accent)
                } else {
                    Image(systemName: "chevron.right").qf(13, .semibold).foregroundStyle(Theme.textDim)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .qfCard(padding: 14, radius: 18)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(c.title). \(Spoken.math(c.formulaLine)).\(learned ? " Learned." : "")")
        .accessibilityHint("Opens the concept with an example and a challenge.")
    }
}
