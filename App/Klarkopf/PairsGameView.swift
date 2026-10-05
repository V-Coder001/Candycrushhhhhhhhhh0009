import Match3Core
import SwiftUI

/// Paare finden: turn two cards per attempt; equal pictures stay open.
struct PairsGameView: View {
    let onFinish: (Double) -> Void

    @State private var round: PairsRound
    @State private var mismatchToken = 0

    static let motifs = ["🌻", "🍎", "🐱", "🏠", "⭐️", "🎈", "🐟", "🌙", "🚲", "☂️", "🍀", "🎵", "🦋", "🍰", "🔑", "⚽️"]

    init(level: Int, seed: UInt64, onFinish: @escaping (Double) -> Void) {
        self.onFinish = onFinish
        _round = State(initialValue: PairsRound(level: level, motifCount: Self.motifs.count, seed: seed))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                KGameTitle(title: "Finden Sie die Paare",
                           subtitle: "Tippen Sie zwei Karten an. Gleiche Bilder bleiben offen.")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: round.columns),
                          spacing: 12) {
                    ForEach(round.cards) { card in
                        Button { tap(card.id) } label: { cardView(card) }
                            .buttonStyle(KPressStyle())
                            .accessibilityLabel(label(for: card))
                    }
                }
                Text("Gefundene Paare: \(round.matchedPairs) von \(round.pairs)")
                    .font(KTheme.body)
                    .foregroundStyle(KTheme.secondary)
            }
            .padding(20)
        }
    }

    private func label(for card: PairsRound.Card) -> String {
        let state = card.isFaceUp || card.isMatched ? "offen" : "verdeckt"
        return "Karte \(card.id + 1), \(state)"
    }

    private func cardView(_ card: PairsRound.Card) -> some View {
        let open = card.isFaceUp || card.isMatched
        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(open ? KTheme.card : KTheme.accent)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(card.isMatched ? KTheme.good : KTheme.line, lineWidth: card.isMatched ? 3 : 1)
            if open {
                Text(Self.motifs[card.motif])
                    .font(.system(size: 46))
            } else {
                Image(systemName: "sparkle")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(card.isMatched ? 0.7 : 1)
        .animation(.easeInOut(duration: 0.2), value: open)
    }

    private func tap(_ index: Int) {
        switch round.flip(index) {
        case .ignored:
            return
        case .first:
            Haptics.tap()
        case .match:
            Haptics.success()
            if round.isComplete {
                let score = round.score
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    onFinish(score)
                }
            }
        case .mismatch:
            mismatchToken += 1
            let token = mismatchToken
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                if token == mismatchToken { round.hideMismatch() }
            }
        }
    }
}
