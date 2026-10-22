import SwiftUI

enum SimKind: String, Identifiable {
    case market, ev, interview
    var id: String { rawValue }
}

/// SIMULATE: three short, educational simulations. Decisions under uncertainty.
struct SimulateScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var presented: SimKind? = nil
    @State private var runID = 0

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SIMULATE").qfLabel(Theme.accent)
                        Text("Decide under uncertainty.").qf(32, .bold, relativeTo: .largeTitle).foregroundStyle(Theme.text)
                        Text("Educational simulations. Not trading or financial advice.").qf(14, .regular, relativeTo: .subheadline).foregroundStyle(Theme.textDim)
                    }
                    .padding(.top, 14)
                    marketCard
                    evCard
                    interviewCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .qfColumn()
        }
        .fullScreenCover(item: $presented) { kind in
            cover(kind)
        }
    }

    @ViewBuilder
    private func cover(_ kind: SimKind) -> some View {
        switch kind {
        case .market:
            MarketMakerView(seed: UInt64(model.save.marketSessions + runID), onClose: { presented = nil }, onRestart: { runID += 1 })
                .id("market\(runID)")
        case .ev:
            EVGameView(seed: UInt64(model.save.evGames + runID), onClose: { presented = nil }, onRestart: { runID += 1 })
                .id("ev\(runID)")
        case .interview:
            InterviewView(seed: UInt64(model.save.interviews.count + runID), onClose: { presented = nil }, onRestart: { runID += 1 })
                .id("iv\(runID)")
        }
    }

    private func open(_ kind: SimKind) {
        Haptics.tap()
        presented = kind
    }

    private var marketCard: some View {
        Button(action: { open(.market) }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("MARKET MAKER").qfLabel(Theme.accent)
                    Spacer()
                    Image(systemName: "arrow.up.right").qf(14, .bold).foregroundStyle(Theme.accent)
                }
                Text("Quote a bid and an ask. Get hit. Manage inventory.")
                    .qf(22, .bold, relativeTo: .title3).foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                OrderBookView(fair: 102.40, marketBid: 101.90, marketAsk: 103.10)
                    .allowsHitTesting(false)
                HStack {
                    if model.save.marketSessions > 0 {
                        Text("\(model.save.marketSessions) SESSION\(model.save.marketSessions == 1 ? "" : "S") · BEST \(Fmt.signed(model.save.marketBestPnL, decimals: 1))").qfLabel()
                    } else {
                        Text("6 ROUNDS · ~2 MIN").qfLabel()
                    }
                    Spacer()
                    Text("ENTER THE DESK").qfLabel(Theme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .qfCard(padding: 18, radius: 26)
            .overlay { RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.accent.opacity(0.35), lineWidth: 1) }
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Market Maker simulation")
        .accessibilityHint("Quote a bid and ask around fair value, then see how the market responds. Six rounds.")
    }

    private var evCard: some View {
        Button(action: { open(.ev) }) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "scalemass").qf(26, .semibold).foregroundStyle(Theme.accent).frame(width: 34)
                VStack(alignment: .leading, spacing: 6) {
                    Text("EV GAME").qfLabel(Theme.accent)
                    Text("Which gamble has the higher expected value?").qf(18, .semibold, relativeTo: .headline)
                        .foregroundStyle(Theme.text).multilineTextAlignment(.leading)
                    Text(model.save.evGames > 0 ? "BEST \(model.save.evBest) / 6 · PLAYED \(model.save.evGames)" : "6 ROUNDS · ~1 MIN").qfLabel()
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .qfCard(padding: 18, radius: 22)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("EV Game")
        .accessibilityHint("Pick the gamble with the higher expected value, then watch the averages converge.")
    }

    private var interviewCard: some View {
        Button(action: { open(.interview) }) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "briefcase").qf(26, .semibold).foregroundStyle(Theme.accent).frame(width: 34)
                VStack(alignment: .leading, spacing: 6) {
                    Text("MOCK QUANT INTERVIEW").qfLabel(Theme.accent)
                    Text("10 questions. 2 minutes. No calculator.").qf(18, .semibold, relativeTo: .headline)
                        .foregroundStyle(Theme.text).multilineTextAlignment(.leading)
                    if let last = model.save.interviews.last {
                        Text("LAST SCORE \(last.correct) / \(last.total) · \(Fmt.percent(last.accuracy)) ACCURACY").qfLabel()
                    } else {
                        Text("SPEED + ACCURACY REPORT").qfLabel()
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .qfCard(padding: 18, radius: 22)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Mock quant interview")
        .accessibilityHint("Ten questions in two minutes with no calculator, then an interview report.")
    }
}
