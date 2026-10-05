import Match3Core
import SwiftUI
import UIKit

/// Chess against the computer. You play White: tap a piece, then one of the marked squares.
struct ChessView: View {
    let onClose: () -> Void

    @AppStorage("wins.chess") private var wins = 0
    @AppStorage("chess.level") private var level = 1
    @State private var game = Chess()
    @State private var selected: Int?
    @State private var thinking = false
    @State private var counted = false

    private static let levelNames = ["Leicht", "Mittel", "Stark"]

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(uiColor: UIColor(hex: 0x6B4A2E)), Color(uiColor: UIColor(hex: 0x3E2A1A))],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                GameTopBar(title: "Schach", onClose: onClose) {
                    HStack(spacing: 8) {
                        CandyIconButton(symbol: "arrow.uturn.backward", color: UIColor(hex: 0xFFB347),
                                        label: "Zug zurücknehmen", size: 46) { undo() }
                            .disabled(!canUndo)
                            .opacity(canUndo ? 1 : 0.5)
                        CandyIconButton(symbol: "arrow.clockwise", color: UIColor(hex: 0x2485E0), label: "Neues Spiel",
                                        size: 46) { restart() }
                    }
                }
                levelPicker
                Text(statusText)
                    .font(Theme.title(19, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(height: 26)
                board
                    .padding(.horizontal, 12)
                Text("Siege gegen den Computer: \(wins)")
                    .font(Theme.title(15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 0)
            }

            if let result = resultText {
                GameOverCard(title: result.title, message: result.message, primary: "Neues Spiel", onPrimary: restart)
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: Parts

    private var levelPicker: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { value in
                Button { level = value } label: {
                    Text(Self.levelNames[value - 1])
                        .font(Theme.title(16, weight: .heavy))
                        .foregroundStyle(level == value ? Color(uiColor: UIColor(hex: 0x3E2A1A)) : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(level == value ? Color.white : Color.white.opacity(0.15)))
                }
                .buttonStyle(CandyPressStyle())
                .accessibilityAddTraits(level == value ? .isSelected : [])
            }
        }
    }

    private var statusText: String {
        if thinking { return "Der Computer überlegt …" }
        if game.status != .playing { return " " }
        return game.isInCheck(.white) ? "Schach! Du bist am Zug." : "Du bist am Zug."
    }

    private var resultText: (title: String, message: String)? {
        switch game.status {
        case .playing: return nil
        case .checkmate(winner: .white): return ("Gewonnen!", "Schachmatt – du hast den Computer besiegt.")
        case .checkmate: return ("Schachmatt", "Diesmal hat der Computer gewonnen. Noch eine Partie?")
        case .stalemate: return ("Patt", "Keiner kann mehr ziehen – unentschieden.")
        case .draw: return ("Remis", "Zu wenig Figuren für ein Matt – unentschieden.")
        }
    }

    private var canUndo: Bool { game.canUndo && !thinking }

    private var board: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 8
            let targets = selected.map { from in Set(game.legalMoves(from: from).map(\.to)) } ?? []
            let checkedKing = game.isInCheck(game.turn) ? game.board.firstIndex(of: Chess.Piece(game.turn, .king)) : nil
            ZStack(alignment: .topLeading) {
                ForEach(0..<64, id: \.self) { i in
                    let row = i / 8, col = i % 8
                    let square = (7 - row) * 8 + col
                    squareView(square, cell: cell, isTarget: targets.contains(square), isChecked: checkedKing == square)
                        .offset(x: CGFloat(col) * cell, y: CGFloat(row) * cell)
                        .onTapGesture { tap(square) }
                }
            }
            .frame(width: side, height: side, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(0.8), lineWidth: 3))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func squareView(_ square: Int, cell: CGFloat, isTarget: Bool, isChecked: Bool) -> some View {
        let light = (Chess.file(square) + Chess.rank(square)) % 2 == 1
        let isLast = game.lastMove.map { $0.from == square || $0.to == square } ?? false
        var fill = Color(uiColor: UIColor(hex: light ? 0xF0D9B5 : 0xB58863))
        if isLast { fill = Color(uiColor: UIColor(hex: light ? 0xF2E27A : 0xD3B84A)) }
        if selected == square { fill = Color(uiColor: UIColor(hex: 0x8CC56B)) }
        if isChecked { fill = Color(uiColor: UIColor(hex: 0xE5534B)) }
        let piece = game.board[square]
        return ZStack {
            Rectangle().fill(fill)
            if let piece {
                Text(piece.symbol)
                    .font(.system(size: cell * 0.78))
                    .foregroundStyle(piece.side == .white ? Color.white : Color(uiColor: UIColor(hex: 0x1E1A16)))
                    .shadow(color: piece.side == .white ? .black.opacity(0.9) : .white.opacity(0.35), radius: 0.8)
                    .shadow(color: piece.side == .white ? .black.opacity(0.6) : .clear, radius: 0.5)
            }
            if isTarget {
                Circle()
                    .fill(Color.black.opacity(piece == nil ? 0.22 : 0))
                    .frame(width: cell * 0.3, height: cell * 0.3)
                if piece != nil {
                    Circle()
                        .stroke(Color.black.opacity(0.3), lineWidth: cell * 0.08)
                        .padding(cell * 0.06)
                }
            }
        }
        .frame(width: cell, height: cell)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(squareName(square, piece: piece))
        .accessibilityAddTraits(.isButton)
    }

    private func squareName(_ square: Int, piece: Chess.Piece?) -> String {
        let name = "\(["a", "b", "c", "d", "e", "f", "g", "h"][Chess.file(square)])\(Chess.rank(square) + 1)"
        guard let piece else { return name }
        let kinds = ["Bauer", "Springer", "Läufer", "Turm", "Dame", "König"]
        return "\(name), \(piece.side == .white ? "weißer" : "schwarzer") \(kinds[piece.kind.rawValue])"
    }

    // MARK: Play

    private func tap(_ square: Int) {
        guard !thinking, game.status == .playing, game.turn == .white else { return }
        if let from = selected, game.legalMoves(from: from).contains(where: { $0.to == square }) {
            var next = game
            next.play(Chess.Move(from: from, to: square))
            withAnimation(.easeOut(duration: 0.15)) {
                game = next
                selected = nil
            }
            moved()
            return
        }
        if game.board[square]?.side == .white, !game.legalMoves(from: square).isEmpty {
            selected = square
            Haptics.tap()
        } else {
            selected = nil
        }
    }

    private func moved() {
        SoundManager.shared.play(.swap, volume: 0.6)
        Haptics.pop()
        guard game.status == .playing else {
            finish()
            return
        }
        thinking = true
        let position = game
        let strength = level
        Task { @MainActor in
            async let reply = Task.detached(priority: .userInitiated) {
                position.computerMove(level: strength, seed: UInt64.random(in: 1...UInt64.max))
            }.value
            try? await Task.sleep(nanoseconds: 450_000_000)
            let move = await reply
            guard thinking else { return }
            if let move {
                var next = game
                next.play(move)
                withAnimation(.easeOut(duration: 0.2)) { game = next }
                SoundManager.shared.play(.swap, volume: 0.6)
            }
            thinking = false
            if game.status != .playing { finish() }
        }
    }

    private func finish() {
        guard !counted else { return }
        counted = true
        if game.status == .checkmate(winner: .white) {
            wins += 1
            SoundManager.shared.play(.win)
            Haptics.success()
        }
    }

    private func undo() {
        guard canUndo else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            game.undo()
            if game.turn == .black && game.canUndo { game.undo() }
            selected = nil
        }
        counted = false
    }

    private func restart() {
        withAnimation {
            game = Chess()
            selected = nil
            thinking = false
            counted = false
        }
    }
}
