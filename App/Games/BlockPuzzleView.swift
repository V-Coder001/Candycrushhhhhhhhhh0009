import Match3Core
import SwiftUI
import UIKit

/// Block-Puzzle: drag shapes from the tray onto the board. A shadow shows where they land.
struct BlockPuzzleView: View {
    let onClose: () -> Void

    @AppStorage("best.blocks") private var best = 0
    @State private var game = BlockPuzzle(seed: Demo.seed ?? UInt64.random(in: 1...UInt64.max))
    @State private var drag: (index: Int, location: CGPoint)?
    @State private var boardFrame: CGRect = .zero
    @State private var flash: Set<BlockPuzzle.Cell> = []
    @State private var praise: String?

    private static let space = "blocks"
    /// How far above the finger a dragged shape floats, so the finger does not hide it.
    private static let lift: CGFloat = 90

    static let colors: [UInt32] = [0xF0303A, 0xFF8A14, 0xFFC727, 0x2FBF45, 0x228BF2, 0xA13FE0, 0xFF4FA3]

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    private var cell: CGFloat { boardFrame.width / CGFloat(BlockPuzzle.size) }

    var body: some View {
        ZStack {
            CandyBackdrop()
            VStack(spacing: 16) {
                GameTopBar(title: "Block-Puzzle", onClose: onClose) {
                    CandyIconButton(symbol: "arrow.clockwise", color: UIColor(hex: 0x2485E0), label: "Neues Spiel",
                                    size: 46) { restart() }
                }
                HStack(spacing: 12) {
                    ScoreBadge(label: "Punkte", value: formatPoints(game.score))
                    ScoreBadge(label: "Rekord", value: formatPoints(max(best, game.score)))
                }
                board
                    .padding(.horizontal, 16)
                tray
                    .padding(.horizontal, 16)
                Spacer(minLength: 0)
            }

            if let drag, let shape = game.hand[drag.index] {
                shapeView(shape, cell: cell)
                    .position(x: drag.location.x, y: drag.location.y - Self.lift)
                    .allowsHitTesting(false)
            }

            if let praise {
                Text(praise)
                    .font(Theme.title(40, weight: .black))
                    .candyText(Color(uiColor: Theme.candy(.purple).darker(0.3)))
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            if game.isOver && drag == nil {
                GameOverCard(title: "Kein Platz mehr",
                             message: "Du hast \(formatPoints(game.score)) Punkte erreicht.",
                             primary: "Neues Spiel", onPrimary: restart)
            }
        }
        .coordinateSpace(name: Self.space)
        .preferredColorScheme(.light)
    }

    // MARK: Board

    private var board: some View {
        let target = dropTarget
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: Theme.boardUI))
            ForEach(0..<(BlockPuzzle.size * BlockPuzzle.size), id: \.self) { i in
                let r = i / BlockPuzzle.size, c = i % BlockPuzzle.size
                Group {
                    if let color = game.board[r][c] {
                        block(color: color, size: cell)
                    } else if let target, target.cells.contains(BlockPuzzle.Cell(r, c)) {
                        block(color: target.color, size: cell).opacity(0.4)
                    } else {
                        RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous)
                            .fill(Color(uiColor: Theme.tileUI))
                            .padding(cell * 0.05)
                    }
                }
                .frame(width: cell, height: cell)
                .overlay(
                    RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous)
                        .fill(.white)
                        .opacity(flash.contains(BlockPuzzle.Cell(r, c)) ? 0.9 : 0)
                )
                .offset(x: CGFloat(c) * cell, y: CGFloat(r) * cell)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { boardFrame = geo.frame(in: .named(Self.space)) }
                    .onChange(of: geo.frame(in: .named(Self.space))) { _, frame in boardFrame = frame }
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spielfeld mit 8 mal 8 Feldern")
    }

    /// Where the dragged shape would land, if it fits there.
    private var dropTarget: (cells: [BlockPuzzle.Cell], color: Int)? {
        guard let drag, let shape = game.hand[drag.index], let origin = origin(of: shape, at: drag.location),
              game.canPlace(shape, row: origin.row, col: origin.col) else { return nil }
        return (shape.cells.map { BlockPuzzle.Cell(origin.row + $0.row, origin.col + $0.col) }, shape.color)
    }

    /// Board cell under the top-left corner of the shape held at `location`.
    private func origin(of shape: BlockPuzzle.Shape, at location: CGPoint) -> BlockPuzzle.Cell? {
        guard cell > 0 else { return nil }
        let left = location.x - CGFloat(shape.width) * cell / 2 - boardFrame.minX
        let top = location.y - Self.lift - CGFloat(shape.height) * cell / 2 - boardFrame.minY
        return BlockPuzzle.Cell(Int((top / cell).rounded()), Int((left / cell).rounded()))
    }

    // MARK: Tray

    private var tray: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.55))
                    if let shape = game.hand.indices.contains(index) ? game.hand[index] : nil {
                        shapeView(shape, cell: max(10, cell * 0.5))
                            .opacity(drag?.index == index ? 0 : (game.fitsAnywhere(shape) ? 1 : 0.35))
                    }
                }
                .frame(height: max(110, cell * 2.8))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                        .onChanged { value in
                            guard game.hand.indices.contains(index), game.hand[index] != nil else { return }
                            if drag == nil { Haptics.tap() }
                            drag = (index, value.location)
                        }
                        .onEnded { value in drop(index, at: value.location) }
                )
                .accessibilityLabel("Form \(index + 1)")
            }
        }
    }

    private func drop(_ index: Int, at location: CGPoint) {
        defer { drag = nil }
        guard game.hand.indices.contains(index), let shape = game.hand[index],
              let origin = origin(of: shape, at: location) else { return }
        guard let placement = game.place(handIndex: index, row: origin.row, col: origin.col) else {
            Haptics.invalid()
            return
        }
        best = max(best, game.score)
        Haptics.pop()
        SoundManager.shared.play(.pop, volume: 0.6)
        guard placement.linesCleared > 0 else { return }
        var cleared: Set<BlockPuzzle.Cell> = []
        for r in placement.clearedRows {
            for c in 0..<BlockPuzzle.size { cleared.insert(BlockPuzzle.Cell(r, c)) }
        }
        for c in placement.clearedCols {
            for r in 0..<BlockPuzzle.size { cleared.insert(BlockPuzzle.Cell(r, c)) }
        }
        flash = cleared
        withAnimation(.easeOut(duration: 0.45)) { flash = [] }
        SoundManager.shared.play(placement.linesCleared > 1 ? .special : .collect,
                                 pitch: 1 + Double(min(game.streak, 6)) * 0.08)
        Haptics.special()
        let words = ["Super!", "Klasse!", "Fantastisch!", "Unglaublich!"]
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            praise = placement.linesCleared > 1 || game.streak > 1 ? words[min(placement.linesCleared + game.streak - 2, 3)] : nil
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeOut(duration: 0.25)) { praise = nil }
        }
    }

    // MARK: Drawing

    private func shapeView(_ shape: BlockPuzzle.Shape, cell: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(shape.cells, id: \.self) { c in
                block(color: shape.color, size: cell)
                    .frame(width: cell, height: cell)
                    .offset(x: CGFloat(c.col) * cell, y: CGFloat(c.row) * cell)
            }
        }
        .frame(width: CGFloat(shape.width) * cell, height: CGFloat(shape.height) * cell, alignment: .topLeading)
    }

    private func block(color index: Int, size: CGFloat) -> some View {
        let color = UIColor(hex: Self.colors[index % Self.colors.count])
        return RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
            .fill(LinearGradient(colors: [Color(uiColor: color.lighter(0.3)), Color(uiColor: color),
                                          Color(uiColor: color.darker(0.2))],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .stroke(Color(uiColor: color.lighter(0.5)), lineWidth: max(1, size * 0.06))
            )
            .padding(size * 0.04)
    }

    private func restart() {
        withAnimation {
            game = BlockPuzzle(seed: UInt64.random(in: 1...UInt64.max))
            praise = nil
        }
    }
}
