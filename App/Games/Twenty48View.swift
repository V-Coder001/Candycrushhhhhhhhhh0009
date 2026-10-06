import Match3Core
import SwiftUI
import UIKit

/// 2048 with swipes. Tiles slide and grow; a 2048 tile is celebrated, but play can go on.
struct Twenty48View: View {
    let onClose: () -> Void

    @AppStorage("best.2048") private var best = 0
    @State private var game = Twenty48(seed: Demo.seed ?? UInt64.random(in: 1...UInt64.max))
    @State private var showWin = false
    @State private var celebrated = false

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            CandyBackdrop(accent: Theme.neonAmber, secondary: Theme.neonPink)
            VStack(spacing: 18) {
                GameTopBar(title: "2048", onClose: onClose) {
                    CandyIconButton(symbol: "arrow.clockwise", color: UIColor(hex: 0x2485E0), label: "Neues Spiel",
                                    size: 46) { restart() }
                }
                HStack(spacing: 12) {
                    ScoreBadge(label: "Punkte", value: formatPoints(game.score))
                    ScoreBadge(label: "Rekord", value: formatPoints(max(best, game.score)))
                }
                Text("Wische, um alle Zahlen zu schieben. Gleiche Zahlen verschmelzen.")
                    .font(Theme.title(15, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                board
                    .padding(.horizontal, 16)
                Spacer(minLength: 0)
            }

            if game.isOver {
                GameOverCard(title: "Keine Züge mehr",
                             message: "Du hast \(formatPoints(game.score)) Punkte erreicht.",
                             primary: "Neues Spiel", onPrimary: restart)
            } else if showWin {
                GameOverCard(title: "2048!",
                             message: "Geschafft! Du kannst weiterspielen und einen noch größeren Stein bauen.",
                             primary: "Neues Spiel", onPrimary: restart,
                             secondary: "Weiterspielen", onSecondary: { withAnimation { showWin = false } })
            }
        }
        .preferredColorScheme(.dark)
    }

    private var board: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let gap: CGFloat = 10
            let cell = (side - gap * CGFloat(Twenty48.size + 1)) / CGFloat(Twenty48.size)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: Theme.boardUI))
                ForEach(0..<(Twenty48.size * Twenty48.size), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: Theme.tileUI))
                        .frame(width: cell, height: cell)
                        .offset(x: gap + CGFloat(i % Twenty48.size) * (cell + gap),
                                y: gap + CGFloat(i / Twenty48.size) * (cell + gap))
                }
                ForEach(game.tiles) { tile in
                    tileView(tile, size: cell)
                        .offset(x: gap + CGFloat(tile.col) * (cell + gap), y: gap + CGFloat(tile.row) * (cell + gap))
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .frame(width: side, height: side)
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Theme.neonAmber, Theme.neonPink], startPoint: .top,
                                             endPoint: .bottom), lineWidth: 1.5))
            .shadow(color: Theme.neonAmber.opacity(0.3), radius: 16)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 18).onEnded(swipe))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spielfeld")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(.up)
            case .decrement: move(.down)
            @unknown default: break
            }
        }
    }

    private func tileView(_ tile: Twenty48.Tile, size: CGFloat) -> some View {
        let color = Self.color(for: tile.value)
        let light = tile.value <= 4
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(uiColor: color.lighter(0.25)), Color(uiColor: color)],
                                     startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.6), lineWidth: 1.5)
            Text("\(tile.value)")
                .font(Theme.title(tile.value < 100 ? size * 0.42 : (tile.value < 1_000 ? size * 0.34 : size * 0.27),
                                  weight: .black))
                .foregroundStyle(light ? Theme.darkInk : .white)
                .shadow(color: light ? .clear : Color(uiColor: color.darker(0.5)), radius: 0, y: 2)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(uiColor: color).opacity(light ? 0.25 : 0.7), radius: tile.value >= 128 ? 14 : 8)
        .scaleEffect(tile.merged ? 1.08 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: tile.merged)
    }

    static func color(for value: Int) -> UIColor {
        let colors: [UInt32] = [0xFFF4D6, 0xFFE3A3, 0xFFB347, 0xFF8A14, 0xF0303A, 0xFF4FA3,
                                0xA13FE0, 0x228BF2, 0x1FB5A8, 0x2FBF45, 0xFFC727]
        var index = 0
        var v = value
        while v > 2 { v /= 2; index += 1 }
        return UIColor(hex: colors[min(index, colors.count - 1)])
    }

    private func swipe(_ value: DragGesture.Value) {
        let dx = value.translation.width, dy = value.translation.height
        if abs(dx) > abs(dy) {
            move(dx > 0 ? .right : .left)
        } else {
            move(dy > 0 ? .down : .up)
        }
    }

    private func move(_ direction: Twenty48.Direction) {
        guard !game.isOver, !showWin else { return }
        let hadGoal = game.reachedGoal
        var next = game
        guard next.move(direction) else {
            Haptics.invalid()
            return
        }
        withAnimation(.easeOut(duration: 0.14)) { game = next }
        Haptics.tap()
        SoundManager.shared.play(.swap, volume: 0.5)
        best = max(best, game.score)
        if game.reachedGoal && !hadGoal && !celebrated {
            celebrated = true
            SoundManager.shared.play(.win)
            withAnimation { showWin = true }
        }
    }

    private func restart() {
        withAnimation {
            game = Twenty48(seed: UInt64.random(in: 1...UInt64.max))
            showWin = false
            celebrated = false
        }
    }
}
