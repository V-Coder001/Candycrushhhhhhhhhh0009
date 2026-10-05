import Match3Core
import SwiftUI
import UIKit

/// Klondike solitaire. Tap a card and it jumps to the best place; tap the stock to draw.
struct SolitaireView: View {
    let onClose: () -> Void

    @AppStorage("wins.solitaire") private var wins = 0
    @State private var game = Klondike(seed: Demo.seed ?? UInt64.random(in: 1...UInt64.max))
    @State private var shake: Int?
    @State private var counted = false
    @Namespace private var cards

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(uiColor: UIColor(hex: 0x2E9E5B)), Color(uiColor: UIColor(hex: 0x1C6E3E))],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                GameTopBar(title: "Solitär", onClose: onClose) {
                    HStack(spacing: 8) {
                        CandyIconButton(symbol: "arrow.uturn.backward", color: UIColor(hex: 0xFFB347),
                                        label: "Zug zurücknehmen", size: 46) { undo() }
                            .disabled(!game.canUndo)
                            .opacity(game.canUndo ? 1 : 0.5)
                        CandyIconButton(symbol: "arrow.clockwise", color: UIColor(hex: 0x2485E0), label: "Neues Spiel",
                                        size: 46) { restart() }
                    }
                }
                HStack {
                    Text("Züge: \(game.moves)")
                    Spacer()
                    Text("Gewonnen: \(wins)")
                }
                .font(Theme.title(16, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)

                GeometryReader { geo in
                    let gap: CGFloat = 6
                    let width = (geo.size.width - gap * 6) / 7
                    let height = width * 1.42
                    VStack(alignment: .leading, spacing: 14) {
                        topRow(width: width, height: height, gap: gap)
                        tableau(width: width, height: height, gap: gap, available: geo.size.height - height - 14)
                    }
                }
                .padding(.horizontal, 12)

                if game.canAutoFinish {
                    CandyCapsuleButton(title: "Automatisch ablegen", color: Theme.greenButtonUI, icon: "sparkles") {
                        withAnimation(.easeInOut(duration: 0.6)) { game.autoFinish() }
                        checkWin()
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 8)
                }
            }

            if game.isWon {
                GameOverCard(title: "Gewonnen!", message: "Alle Karten liegen auf den Stapeln – in \(game.moves) Zügen.",
                             primary: "Neues Spiel", onPrimary: restart)
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: Layout

    private func topRow(width: CGFloat, height: CGFloat, gap: CGFloat) -> some View {
        HStack(spacing: gap) {
            // Stock: tap to draw, or to turn the waste over when it is empty.
            Button { withAnimation(.easeOut(duration: 0.2)) { game.draw() } } label: {
                if game.stock.isEmpty {
                    emptySlot(width: width, height: height, symbol: game.waste.isEmpty ? nil : "arrow.clockwise")
                } else {
                    cardBack(width: width, height: height)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(game.stock.isEmpty ? "Ablage umdrehen" : "Karte ziehen")

            ZStack {
                emptySlot(width: width, height: height, symbol: nil)
                if let card = game.waste.last {
                    cardView(card, width: width, height: height)
                        .onTapGesture { tap(.waste) }
                }
            }

            Color.clear.frame(width: width, height: height)

            ForEach(0..<4, id: \.self) { f in
                ZStack {
                    emptySlot(width: width, height: height, symbol: "a.circle")
                    if let card = game.foundations[f].last {
                        cardView(card, width: width, height: height)
                            .onTapGesture { tap(.foundation(f)) }
                    }
                }
            }
        }
    }

    private func tableau(width: CGFloat, height: CGFloat, gap: CGFloat, available: CGFloat) -> some View {
        HStack(alignment: .top, spacing: gap) {
            ForEach(0..<7, id: \.self) { t in
                let column = game.tableau[t]
                let downStep = height * 0.14
                let downs = column.prefix { !$0.faceUp }.count
                let ups = column.count - downs
                let room = available - height - CGFloat(downs) * downStep
                let upStep = ups > 1 ? min(height * 0.3, max(height * 0.16, room / CGFloat(ups - 1))) : 0
                ZStack(alignment: .top) {
                    emptySlot(width: width, height: height, symbol: nil)
                    ForEach(Array(column.enumerated()), id: \.element.id) { index, card in
                        let y = CGFloat(min(index, downs)) * downStep + CGFloat(max(0, index - downs)) * upStep
                        Group {
                            if card.faceUp {
                                cardView(card, width: width, height: height)
                                    .onTapGesture { tap(.tableau(t), index: index) }
                            } else {
                                cardBack(width: width, height: height)
                            }
                        }
                        .offset(y: y)
                    }
                }
                .frame(width: width, alignment: .top)
                .modifier(Shake(amount: shake == t ? 1 : 0))
            }
        }
    }

    // MARK: Cards

    private func cardView(_ card: PlayingCard, width: CGFloat, height: CGFloat) -> some View {
        let color = card.suit.isRed ? Color(uiColor: UIColor(hex: 0xD62B36)) : Color(uiColor: UIColor(hex: 0x1E1E28))
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
            VStack(alignment: .leading, spacing: -2) {
                Text(card.rankText)
                    .font(.system(size: width * 0.36, weight: .bold, design: .rounded))
                Text(card.suit.symbol)
                    .font(.system(size: width * 0.3))
            }
            .foregroundStyle(color)
            .padding(.leading, width * 0.08)
            .padding(.top, width * 0.04)
            Text(card.suit.symbol)
                .font(.system(size: width * 0.62))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(width * 0.08)
        }
        .frame(width: width, height: height)
        .matchedGeometryEffect(id: card.id, in: cards)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName(card))
        .accessibilityAddTraits(.isButton)
    }

    private func cardBack(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
            .fill(LinearGradient(colors: [Color(uiColor: Theme.accentUI.lighter(0.2)), Color(uiColor: Theme.accentUI)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.09, style: .continuous)
                    .stroke(.white.opacity(0.7), lineWidth: 1.5)
                    .padding(width * 0.08)
            )
            .overlay(Image(systemName: "heart.fill").font(.system(size: width * 0.3)).foregroundStyle(.white.opacity(0.5)))
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
    }

    private func emptySlot(width: CGFloat, height: CGFloat, symbol: String?) -> some View {
        RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
            .stroke(.white.opacity(0.45), lineWidth: 1.5)
            .background(RoundedRectangle(cornerRadius: width * 0.12, style: .continuous).fill(.black.opacity(0.08)))
            .overlay {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: width * 0.36, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: width, height: height)
    }

    private func accessibilityName(_ card: PlayingCard) -> String {
        let suits = ["Herz", "Karo", "Kreuz", "Pik"]
        let ranks = [1: "Ass", 11: "Bube", 12: "Dame", 13: "König"]
        return "\(suits[card.suit.rawValue]) \(ranks[card.rank] ?? "\(card.rank)")"
    }

    // MARK: Actions

    private func tap(_ pile: Klondike.Pile, index: Int? = nil) {
        var next = game
        guard next.autoMove(from: pile, index: index) != nil else {
            Haptics.invalid()
            if case let .tableau(t) = pile {
                withAnimation(.linear(duration: 0.3)) { shake = t }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    shake = nil
                }
            }
            return
        }
        withAnimation(.easeOut(duration: 0.22)) { game = next }
        Haptics.tap()
        SoundManager.shared.play(.swap, volume: 0.4)
        checkWin()
    }

    private func checkWin() {
        guard game.isWon, !counted else { return }
        counted = true
        wins += 1
        SoundManager.shared.play(.win)
        Haptics.success()
    }

    private func undo() {
        withAnimation(.easeOut(duration: 0.2)) { game.undo() }
    }

    private func restart() {
        withAnimation {
            game = Klondike(seed: UInt64.random(in: 1...UInt64.max))
            counted = false
        }
    }
}

/// A short sideways wiggle for a move that does not fit.
private struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 6 * sin(amount * .pi * 4), y: 0))
    }
}
