import SwiftUI

struct BookRow: Identifiable {
    enum Kind { case ask, bid, fair, youAsk, youBid }
    let id: String
    let price: Double
    let size: Int
    let kind: Kind
}

/// A miniature, animated limit-order book. Competing depth appears and disappears every tick;
/// your quotes are inserted at their exact price. Educational simulation only.
struct OrderBookView: View {
    let fair: Double
    let marketBid: Double
    let marketAsk: Double
    var myBid: Double? = nil
    var myAsk: Double? = nil
    var filledSide: Side? = nil
    @State private var start = Date()

    private func depth(_ price: Double, _ level: Int, _ tick: Int) -> Int {
        let h = stableHash("\(Int((price * 100).rounded())):\(tick)")
        var size = 24 + Int(h % 60) + level * 7
        if h % 9 == 0 { size = 8 }
        return min(size, 100)
    }

    private func rows(tick: Int) -> [BookRow] {
        var out: [BookRow] = []
        for k in 0..<4 {
            let ap = round2(marketAsk + 0.10 * Double(k))
            let bp = round2(marketBid - 0.10 * Double(k))
            out.append(BookRow(id: "a\(k)", price: ap, size: depth(ap, k, tick), kind: .ask))
            out.append(BookRow(id: "b\(k)", price: bp, size: depth(bp, k, tick), kind: .bid))
        }
        out.append(BookRow(id: "fair", price: fair, size: 0, kind: .fair))
        if let a = myAsk { out.append(BookRow(id: "youA", price: a, size: 100, kind: .youAsk)) }
        if let b = myBid { out.append(BookRow(id: "youB", price: b, size: 100, kind: .youBid)) }
        return out.sorted { x, y in
            if x.price != y.price { return x.price > y.price }
            return x.id < y.id
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("SELL").qfLabel(Theme.bad).frame(maxWidth: .infinity, alignment: .leading)
            TimelineView(.periodic(from: start, by: 0.9)) { ctx in
                let tick = Int(ctx.date.timeIntervalSince(start) / 0.9)
                VStack(spacing: 3) {
                    ForEach(rows(tick: tick)) { row in
                        BookRowView(row: row, fair: fair, filledSide: filledSide)
                    }
                }
                .animation(Motion.smooth, value: tick)
            }
            Text("BUY").qfLabel(Theme.accent).frame(maxWidth: .infinity, alignment: .leading)
        }
        .qfCard(padding: 14, radius: 20, fill: Theme.bgRaised)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Order book")
        .accessibilityValue(summary)
    }

    private var summary: String {
        var s = "Fair value \(Fmt.price(fair)). Market \(Fmt.price(marketBid)) bid, \(Fmt.price(marketAsk)) offer."
        if let b = myBid, let a = myAsk { s += " Your quote \(Fmt.price(b)) bid, \(Fmt.price(a)) offer." }
        return s
    }
}

struct BookRowView: View {
    let row: BookRow
    let fair: Double
    let filledSide: Side?

    var body: some View {
        if row.kind == .fair {
            fairRow
        } else {
            levelRow
        }
    }

    private var fairRow: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Theme.lineStrong).frame(height: 1)
            Text("FAIR VALUE \(Fmt.price(row.price))").qfLabel(Theme.text)
            Rectangle().fill(Theme.lineStrong).frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    private var isYou: Bool { row.kind == .youAsk || row.kind == .youBid }

    private var barColor: Color {
        switch row.kind {
        case .ask: return Theme.bad.opacity(0.55)
        case .bid: return Theme.accent.opacity(0.5)
        case .youAsk: return Theme.blue
        case .youBid: return Theme.accent
        case .fair: return Color.clear
        }
    }

    private var youLabel: String {
        switch row.kind {
        case .youAsk: return "YOU · OFFER"
        case .youBid: return "YOU · BID"
        default: return "\(row.size)"
        }
    }

    private var justFilled: Bool {
        (row.kind == .youAsk && filledSide == .buy) || (row.kind == .youBid && filledSide == .sell)
    }

    private var levelRow: some View {
        HStack(spacing: 10) {
            Text(Fmt.price(row.price))
                .qf(13, .semibold, design: .monospaced, relativeTo: .caption)
                .monospacedDigit()
                .foregroundStyle(isYou ? Theme.text : Theme.textDim)
                .frame(width: 62, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(barColor)
                        .frame(width: max(4, geo.size.width * CGFloat(row.size) / 100))
                }
            }
            .frame(height: 14)
            Text(youLabel)
                .qf(11, .semibold, design: .monospaced, relativeTo: .caption)
                .foregroundStyle(isYou ? Theme.text : Theme.textDim)
                .frame(width: 84, alignment: .trailing)
        }
        .padding(.vertical, isYou ? 3 : 0)
        .padding(.horizontal, isYou ? 6 : 0)
        .background { RoundedRectangle(cornerRadius: 8, style: .continuous).fill(isYou ? Theme.surfaceHigh : Color.clear) }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isYou ? barColor : Color.clear, lineWidth: justFilled ? 2 : 1)
        }
        .scaleEffect(justFilled ? 1.03 : 1.0)
        .animation(Motion.spring, value: justFilled)
    }
}
