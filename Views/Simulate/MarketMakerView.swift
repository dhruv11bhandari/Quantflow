import SwiftUI
import Charts

struct PnLRow: Identifiable {
    let id: Int
    let label: String
    let value: Double
}

/// MARKET MAKER — a small, honest model of pricing, spread, adverse selection and inventory.
struct MarketMakerView: View {
    let onClose: () -> Void
    let onRestart: () -> Void
    @EnvironmentObject private var model: AppModel
    @StateObject private var session: MarketSession

    init(seed: UInt64, onClose: @escaping () -> Void, onRestart: @escaping () -> Void) {
        self.onClose = onClose
        self.onRestart = onRestart
        _session = StateObject(wrappedValue: MarketSession(seed: seed))
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 0) {
                topBar
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        switch session.phase {
                        case .intro: intro
                        case .quoting: quoting
                        case .result: resultView
                        case .summary: summary
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .qfColumn()
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            IconButton(symbol: "xmark", label: "Close Market Maker", action: onClose)
            VStack(alignment: .leading, spacing: 2) {
                Text("MARKET MAKER").qfLabel(Theme.text)
                if session.phase == .quoting || session.phase == .result {
                    Text("ROUND \(session.round + 1) OF \(session.scenarios.count)").qfLabel(Theme.textDim)
                }
            }
            Spacer()
            if !session.results.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("P&L").qfLabel()
                    Text(Fmt.signed(session.cumulativePnL, decimals: 1))
                        .qf(20, .bold, design: .monospaced, relativeTo: .title3)
                        .monospacedDigit()
                        .foregroundStyle(session.cumulativePnL >= 0 ? Theme.accent : Theme.bad)
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Total profit and loss")
                .accessibilityValue(Fmt.signed(session.cumulativePnL, decimals: 1))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    // MARK: Intro

    private func step(_ n: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(n).qf(13, .bold, design: .monospaced, relativeTo: .footnote).foregroundStyle(Theme.bg)
                .frame(width: 26, height: 26).background { Circle().fill(Theme.accent) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).qf(17, .semibold, relativeTo: .headline).foregroundStyle(Theme.text)
                Text(detail).qf(14, .regular, relativeTo: .subheadline).foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("QF-01 · SIX ROUNDS").qfLabel(Theme.accent)
            Text("Quote the market.\nManage the risk.")
                .qf(38, .bold, relativeTo: .largeTitle).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 14) {
                step("1", "Read the market", "You know fair value. Competitors quote around it.")
                step("2", "Set your bid and ask", "Tighter wins flow. Wider earns more per trade.")
                step("3", "An order arrives", "You earn the spread, but inventory moves with the price.")
            }
            .qfCard(padding: 18, radius: 22)
            OrderBookView(fair: 102.40, marketBid: 101.90, marketAsk: 103.10)
            Text("Educational simulation. Not trading or financial advice.").qfLabel()
            PrimaryButton(title: "ENTER THE DESK", symbol: "arrow.right") { session.begin() }
        }
    }

    // MARK: Shared header

    private var assetHeader: some View {
        let s = session.scenario
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ASSET  \(s.asset)").qfLabel()
                Text("FAIR VALUE").qfLabel(Theme.accent)
                Text(Fmt.price(s.fair))
                    .qf(46, .bold, design: .monospaced, relativeTo: .largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                VolatilityMeter(volatility: s.volatility)
                Text("INVENTORY \(session.inventory > 0 ? "+" : (session.inventory < 0 ? Fmt.minus : ""))\(abs(session.inventory))")
                    .qf(13, .bold, design: .monospaced, relativeTo: .footnote)
                    .foregroundStyle(abs(session.inventory) > 40 ? Theme.warn : Theme.text)
                Text("MARKET \(Fmt.price(s.marketBid)) × \(Fmt.price(s.marketAsk))")
                    .qf(12, .semibold, design: .monospaced, relativeTo: .caption)
                    .foregroundStyle(Theme.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qfCard(padding: 16, radius: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Asset \(s.asset). Fair value \(Fmt.price(s.fair)). Volatility \(s.volatility.rawValue). Inventory \(session.inventory). Market \(Fmt.price(s.marketBid)) bid, \(Fmt.price(s.marketAsk)) offer.")
    }

    // MARK: Quoting

    private var shadeTip: String {
        let inv = session.inventory
        if inv > 20 { return "You're long \(inv). Lower both quotes a little to attract buyers and shed risk." }
        if inv < -20 { return "You're short \(abs(inv)). Raise both quotes a little to attract sellers." }
        return "Quote inside the market to win flow, but keep an edge over fair value."
    }

    private var quoting: some View {
        let s = session.scenario
        return VStack(spacing: 16) {
            assetHeader
            OrderBookView(fair: s.fair, marketBid: s.marketBid, marketAsk: s.marketAsk, myBid: session.bid, myAsk: session.ask)
            VStack(spacing: 12) {
                QuoteStepperRow(title: "BID", value: session.bid, edge: s.fair - session.bid,
                                minus: { session.nudgeBid(-1) }, plus: { session.nudgeBid(1) })
                QuoteStepperRow(title: "ASK", value: session.ask, edge: session.ask - s.fair,
                                minus: { session.nudgeAsk(-1) }, plus: { session.nudgeAsk(1) })
                Divider()
                HStack {
                    Text("SPREAD").qfLabel()
                    Text(Fmt.price(session.ask - session.bid)).qf(15, .bold, design: .monospaced, relativeTo: .body).foregroundStyle(Theme.text)
                    Spacer()
                    Button(action: { Haptics.select(); session.resetQuote() }) {
                        Text("RESET TO MARKET").qfLabel(Theme.accent)
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Reset your quote to the market")
                }
            }
            .qfCard(padding: 16, radius: 22)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb").qf(13, .semibold).foregroundStyle(Theme.warn)
                Text(shadeTip).qf(14, .regular, relativeTo: .subheadline).foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryButton(title: "POST QUOTES", symbol: "arrow.up.right", enabled: session.canPost) { session.post() }
        }
    }

    // MARK: Result

    private func orderBanner(_ o: IncomingOrder) -> some View {
        let buy = o.side == .buy
        let size = buy ? "+\(o.size)" : "\(Fmt.minus)\(o.size)"
        return HStack(spacing: 12) {
            Image(systemName: buy ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                .qf(28, .semibold).foregroundStyle(buy ? Theme.accent : Theme.bad)
            VStack(alignment: .leading, spacing: 2) {
                Text("INCOMING ORDER").qfLabel()
                Text("\(o.side.title) ORDER  \(size) @ \(Fmt.price(o.limit))")
                    .qf(20, .bold, design: .monospaced, relativeTo: .title3).foregroundStyle(Theme.text)
                    .minimumScaleFactor(0.6).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .qfCard(padding: 14, radius: 18)
        .accessibilityElement(children: .combine)
        .transition(AnyTransition.move(edge: .top).combined(with: AnyTransition.opacity))
    }

    private func lesson(_ r: MMRoundResult, _ s: MMScenario) -> String {
        if !r.filled {
            switch r.reason {
            case .marketTookIt: return "The market was cheaper, so the order went there. Quote inside the market to win flow."
            case .priceTooHigh: return "Your offer was above what the buyer would pay. Lower it, but stay above fair value."
            case .priceTooLow: return "Your bid was below what the seller would accept. Raise it, but stay below fair value."
            case .filled: return ""
            }
        }
        if r.spreadPnL < 0 { return "You traded through fair value. That's negative edge: you paid to trade." }
        if s.order.informed && r.inventoryPnL < 0 { return "Informed flow: the price moved against your new inventory. Wider quotes pay for that risk." }
        if abs(r.inventoryAfter) > 60 { return "Inventory is getting heavy. Skew your quotes to bring it back toward zero." }
        return "Clean trade: edge captured and a small inventory move."
    }

    private func pnlRow(_ title: String, _ value: Double, bold: Bool = false) -> some View {
        HStack {
            Text(title).qfLabel(bold ? Theme.text : Theme.textDim)
            Spacer()
            Text(Fmt.signed(value, decimals: 1))
                .qf(bold ? 22 : 17, .bold, design: .monospaced, relativeTo: .body)
                .monospacedDigit()
                .foregroundStyle(value >= 0 ? Theme.accent : Theme.bad)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private func resultCard(_ r: MMRoundResult, _ s: MMScenario) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: r.filled ? "checkmark.circle.fill" : "minus.circle.fill")
                    .qf(22, .semibold).foregroundStyle(r.filled ? Theme.accent : Theme.warn)
                Text(r.filled ? "FILLED" : "NO FILL").qf(18, .bold, design: .monospaced, relativeTo: .headline)
                    .foregroundStyle(r.filled ? Theme.accent : Theme.warn)
            }
            Text(r.note).qf(15, .medium, design: .monospaced, relativeTo: .subheadline).foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            VStack(spacing: 10) {
                pnlRow("SPREAD EDGE", r.spreadPnL)
                pnlRow("INVENTORY MOVE", r.inventoryPnL)
                pnlRow("ROUND P&L", r.total, bold: true)
            }
            Divider()
            HStack {
                Text("FAIR VALUE").qfLabel()
                Spacer()
                Text("\(Fmt.price(r.fairBefore)) → \(Fmt.price(r.fairAfter))").qf(15, .semibold, design: .monospaced, relativeTo: .body).foregroundStyle(Theme.text)
            }
            HStack {
                Text("INVENTORY").qfLabel()
                Spacer()
                Text("\(r.inventoryBefore) → \(r.inventoryAfter)").qf(15, .semibold, design: .monospaced, relativeTo: .body).foregroundStyle(Theme.text)
            }
            HStack {
                Text("RISK (1σ)").qfLabel()
                Spacer()
                Text("±\(Fmt.num(r.risk, maxDecimals: 1))").qf(15, .semibold, design: .monospaced, relativeTo: .body).foregroundStyle(Theme.textDim)
            }
            Text(lesson(r, s)).qf(14, .regular, relativeTo: .subheadline).foregroundStyle(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .qfCard(padding: 16, radius: 22)
    }

    @ViewBuilder
    private var resultView: some View {
        if let r = session.lastResult {
            let s = session.scenario
            VStack(spacing: 16) {
                orderBanner(s.order)
                OrderBookView(fair: s.fair, marketBid: s.marketBid, marketAsk: s.marketAsk, myBid: r.bid, myAsk: r.ask,
                              filledSide: r.filled ? s.order.side : nil)
                resultCard(r, s)
                PrimaryButton(title: session.isLastRound ? "SEE DESK REVIEW" : "NEXT ROUND", symbol: "arrow.right") {
                    session.nextRound(model)
                }
            }
        }
    }

    // MARK: Summary

    private var pnlRows: [PnLRow] {
        session.results.enumerated().map { PnLRow(id: $0.offset, label: "R\($0.offset + 1)", value: $0.element.total) }
    }

    private var pnlSpoken: String {
        pnlRows.map { "\($0.label) \(Fmt.signed($0.value, decimals: 1))" }.joined(separator: ", ")
    }

    @ViewBuilder
    private var summary: some View {
        if let rv = session.review {
            VStack(alignment: .leading, spacing: 16) {
                Text("DESK REVIEW").qfLabel(Theme.accent)
                Text(rv.headline).qf(28, .bold, relativeTo: .title).foregroundStyle(Theme.text)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Fmt.signed(rv.totalPnL, decimals: 1))
                        .qf(60, .bold, design: .monospaced, relativeTo: .largeTitle)
                        .monospacedDigit()
                        .foregroundStyle(rv.totalPnL >= 0 ? Theme.accent : Theme.bad)
                    Text("P&L (₹)").qfLabel()
                }
                Chart(pnlRows) { row in
                    BarMark(x: .value("Round", row.label), y: .value("P&L", row.value))
                        .foregroundStyle(row.value >= 0 ? Theme.accent : Theme.bad)
                }
                .chartLegend(.hidden)
                .frame(height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Profit and loss by round")
                .accessibilityValue(pnlSpoken)
                VStack(spacing: 12) {
                    ForEach(0..<rv.lines.count, id: \.self) { i in
                        HStack {
                            Text(rv.lines[i].title).qfLabel()
                            Spacer()
                            Text(rv.lines[i].value).qf(16, .bold, design: .monospaced, relativeTo: .body).foregroundStyle(Theme.text)
                            Text(rv.lines[i].verdict.uppercased()).qfLabel(Theme.accent).frame(width: 118, alignment: .trailing)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .qfCard(padding: 16, radius: 20)
                if let rw = session.reward {
                    HStack {
                        Text("MARKET MAKING SKILL").qfLabel()
                        Spacer()
                        Text("\(Int(model.skills.marketMaking.rounded()))").qf(18, .bold, design: .monospaced, relativeTo: .headline).foregroundStyle(Theme.text)
                        Text("+\(rw.xp) XP").qfLabel(Theme.accent)
                    }
                    .accessibilityElement(children: .combine)
                }
                Text("Educational simulation. Real markets are far more complex; this is not trading advice.").qfLabel()
                PrimaryButton(title: "RUN A NEW SESSION", symbol: "arrow.clockwise", action: onRestart)
                SecondaryButton(title: "DONE", action: onClose)
            }
        }
    }
}
