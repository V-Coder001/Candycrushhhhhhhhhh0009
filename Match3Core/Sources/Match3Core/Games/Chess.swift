/// Chess with all rules (castling, en passant, promotion, check, mate, stalemate) and a small
/// computer opponent. Squares are numbered 0...63: index = rank * 8 + file, rank 0 is White's back rank.
public struct Chess {
    public enum Side: Hashable {
        case white, black

        public var opposite: Side { self == .white ? .black : .white }
    }

    public enum Kind: Int, CaseIterable {
        case pawn, knight, bishop, rook, queen, king

        /// Material in centipawns.
        var value: Int { [100, 320, 330, 500, 900, 0][rawValue] }
    }

    public struct Piece: Hashable {
        public let side: Side
        public let kind: Kind

        public init(_ side: Side, _ kind: Kind) {
            self.side = side
            self.kind = kind
        }

        /// Filled chess glyph with the text presentation selector, so iOS never shows an emoji pawn.
        public var symbol: String {
            ["\u{265F}", "\u{265E}", "\u{265D}", "\u{265C}", "\u{265B}", "\u{265A}"][kind.rawValue] + "\u{FE0E}"
        }
    }

    public struct Move: Hashable {
        public let from: Int
        public let to: Int
        public var promotion: Kind?

        public init(from: Int, to: Int, promotion: Kind? = nil) {
            self.from = from
            self.to = to
            self.promotion = promotion
        }
    }

    public enum Status: Equatable {
        case playing
        case checkmate(winner: Side)
        case stalemate
        case draw
    }

    public private(set) var board: [Piece?]
    public private(set) var turn: Side = .white
    /// The square a pawn could capture onto en passant, if the last move was a double step.
    public private(set) var enPassant: Int?
    public private(set) var lastMove: Move?
    private var castling: Set<Int> = [0, 7, 56, 63]  // rook squares that may still castle
    private var history: [Chess] = []

    public init() {
        board = Array(repeating: nil, count: 64)
        let back: [Kind] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for file in 0..<8 {
            board[file] = Piece(.white, back[file])
            board[8 + file] = Piece(.white, .pawn)
            board[48 + file] = Piece(.black, .pawn)
            board[56 + file] = Piece(.black, back[file])
        }
    }

    /// For tests: pieces from an 8-line diagram, top line = rank 8. Upper case white, lower case black,
    /// letters p n b r q k, `.` empty. Castling only where king and rook still stand at home.
    public init(diagram: [String], turn: Side = .white) {
        board = Array(repeating: nil, count: 64)
        let kinds: [Character: Kind] = ["p": .pawn, "n": .knight, "b": .bishop, "r": .rook, "q": .queen, "k": .king]
        for (line, text) in diagram.enumerated() {
            for (file, ch) in text.enumerated() {
                guard let kind = kinds[Character(ch.lowercased())] else { continue }
                board[(7 - line) * 8 + file] = Piece(ch.isUppercase ? .white : .black, kind)
            }
        }
        self.turn = turn
        castling = Set([0, 7, 56, 63].filter { square in
            let king = square < 8 ? 4 : 60
            return board[square] == Piece(square < 8 ? .white : .black, .rook)
                && board[king] == Piece(square < 8 ? .white : .black, .king)
        })
    }

    public static func file(_ square: Int) -> Int { square % 8 }
    public static func rank(_ square: Int) -> Int { square / 8 }

    public var canUndo: Bool { !history.isEmpty }

    // MARK: Moves

    public func legalMoves() -> [Move] {
        pseudoMoves(for: turn).filter { move in
            var next = self
            next.apply(move)
            return !next.isInCheck(turn)
        }
    }

    public func legalMoves(from square: Int) -> [Move] {
        legalMoves().filter { $0.from == square }
    }

    public func isInCheck(_ side: Side) -> Bool {
        guard let king = board.firstIndex(of: Piece(side, .king)) else { return false }
        return isAttacked(king, by: side.opposite)
    }

    public var status: Status {
        if legalMoves().isEmpty {
            return isInCheck(turn) ? .checkmate(winner: turn.opposite) : .stalemate
        }
        // Only kings, or king and one minor piece against king: nobody can win.
        let pieces = board.compactMap { $0 }.filter { $0.kind != .king }
        if pieces.isEmpty || (pieces.count == 1 && [.knight, .bishop].contains(pieces[0].kind)) {
            return .draw
        }
        return .playing
    }

    /// Plays a legal move; returns false for an illegal one. Pawns reaching the last rank become queens
    /// unless the move names another piece.
    @discardableResult
    public mutating func play(_ move: Move) -> Bool {
        var move = move
        if move.promotion == nil, board[move.from]?.kind == .pawn, Self.rank(move.to) == 0 || Self.rank(move.to) == 7 {
            move.promotion = .queen
        }
        guard legalMoves().contains(move) else { return false }
        var snapshot = self
        snapshot.history = []
        history.append(snapshot)
        apply(move)
        return true
    }

    public mutating func undo() {
        guard let previous = history.popLast() else { return }
        let rest = history
        self = previous
        history = rest
    }

    // MARK: Computer

    /// Picks a move for the side to move. Level 1 plays loosely, level 3 looks three half-moves ahead.
    public func computerMove(level: Int, seed: UInt64) -> Move? {
        var rng = GameRandom(seed: seed)
        let moves = legalMoves()
        guard !moves.isEmpty else { return nil }
        let depth = max(1, min(3, level))
        var scored: [(Move, Int)] = []
        for move in ordered(moves) {
            var next = self
            next.apply(move)
            scored.append((move, -next.search(depth: depth - 1, alpha: -1_000_000, beta: 1_000_000)))
        }
        let best = scored.map(\.1).max() ?? 0
        // Easier levels accept moves that are a little worse, so they make human mistakes.
        let slack = level <= 1 ? 120 : (level == 2 ? 25 : 0)
        let candidates = scored.filter { $0.1 >= best - slack }.map(\.0)
        return candidates[rng.int(candidates.count)]
    }

    private func search(depth: Int, alpha: Int, beta: Int) -> Int {
        let moves = legalMoves()
        if moves.isEmpty {
            return isInCheck(turn) ? -100_000 - depth : 0
        }
        guard depth > 0 else { return evaluate() }
        var alpha = alpha
        for move in ordered(moves) {
            var next = self
            next.apply(move)
            let score = -next.search(depth: depth - 1, alpha: -beta, beta: -alpha)
            if score >= beta { return score }
            alpha = max(alpha, score)
        }
        return alpha
    }

    /// Captures of valuable pieces first, which makes the alpha-beta search much faster.
    private func ordered(_ moves: [Move]) -> [Move] {
        moves.sorted { a, b in
            (board[a.to]?.kind.value ?? 0) + (a.promotion != nil ? 800 : 0)
                > (board[b.to]?.kind.value ?? 0) + (b.promotion != nil ? 800 : 0)
        }
    }

    /// Material plus a small bonus for active squares, from the view of the side to move.
    func evaluate() -> Int {
        var score = 0
        for (square, piece) in board.enumerated() {
            guard let piece else { continue }
            let file = Self.file(square)
            let rank = piece.side == .white ? Self.rank(square) : 7 - Self.rank(square)
            let center = 3 - Int(Double(abs(2 * file - 7)) / 2)  // 0 at the edge, 3 in the middle
            var value = piece.kind.value
            switch piece.kind {
            case .pawn: value += rank * 8 + (file > 1 && file < 6 ? rank * 4 : 0)
            case .knight, .bishop: value += center * 8 + (rank > 0 ? 10 : 0)
            case .queen: value += center * 2
            case .rook: value += rank == 6 ? 20 : 0
            case .king: value += rank == 0 ? 10 : -20
            }
            score += piece.side == turn ? value : -value
        }
        return score
    }

    // MARK: Board mechanics

    private mutating func apply(_ move: Move) {
        guard let piece = board[move.from] else { return }
        // En passant capture removes the pawn beside the target square.
        if piece.kind == .pawn, move.to == enPassant, board[move.to] == nil {
            board[move.to + (piece.side == .white ? -8 : 8)] = nil
        }
        // Castling also moves the rook.
        if piece.kind == .king, abs(move.to - move.from) == 2 {
            let kingSide = move.to > move.from
            let rookFrom = kingSide ? move.from + 3 : move.from - 4
            let rookTo = kingSide ? move.from + 1 : move.from - 1
            board[rookTo] = board[rookFrom]
            board[rookFrom] = nil
        }
        board[move.to] = move.promotion.map { Piece(piece.side, $0) } ?? piece
        board[move.from] = nil

        enPassant = piece.kind == .pawn && abs(move.to - move.from) == 16 ? (move.from + move.to) / 2 : nil
        if piece.kind == .king {
            castling.subtract(piece.side == .white ? [0, 7] : [56, 63])
        }
        castling.remove(move.from)
        castling.remove(move.to)
        lastMove = move
        turn = turn.opposite
    }

    private static let knightSteps = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
    private static let kingSteps = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    private static let straight = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    private static let diagonal = [(1, 1), (1, -1), (-1, 1), (-1, -1)]

    private static func offset(_ square: Int, _ df: Int, _ dr: Int) -> Int? {
        let f = file(square) + df, r = rank(square) + dr
        return (0..<8).contains(f) && (0..<8).contains(r) ? r * 8 + f : nil
    }

    func isAttacked(_ square: Int, by side: Side) -> Bool {
        // Pawns attack diagonally forward from their own point of view.
        let pawnRank = side == .white ? -1 : 1
        for df in [-1, 1] {
            if let s = Self.offset(square, df, pawnRank), board[s] == Piece(side, .pawn) { return true }
        }
        for (df, dr) in Self.knightSteps {
            if let s = Self.offset(square, df, dr), board[s] == Piece(side, .knight) { return true }
        }
        for (df, dr) in Self.kingSteps {
            if let s = Self.offset(square, df, dr), board[s] == Piece(side, .king) { return true }
        }
        for (directions, kinds) in [(Self.straight, [Kind.rook, .queen]), (Self.diagonal, [Kind.bishop, .queen])] {
            for (df, dr) in directions {
                var current = square
                while let s = Self.offset(current, df, dr) {
                    if let piece = board[s] {
                        if piece.side == side && kinds.contains(piece.kind) { return true }
                        break
                    }
                    current = s
                }
            }
        }
        return false
    }

    private func pseudoMoves(for side: Side) -> [Move] {
        var moves: [Move] = []
        for (square, piece) in board.enumerated() {
            guard let piece, piece.side == side else { continue }
            switch piece.kind {
            case .pawn:
                let dir = side == .white ? 1 : -1
                let startRank = side == .white ? 1 : 6
                let lastRank = side == .white ? 7 : 0
                func add(_ to: Int) {
                    if Self.rank(to) == lastRank {
                        for kind in [Kind.queen, .rook, .bishop, .knight] { moves.append(Move(from: square, to: to, promotion: kind)) }
                    } else {
                        moves.append(Move(from: square, to: to))
                    }
                }
                if let one = Self.offset(square, 0, dir), board[one] == nil {
                    add(one)
                    if Self.rank(square) == startRank, let two = Self.offset(square, 0, 2 * dir), board[two] == nil {
                        moves.append(Move(from: square, to: two))
                    }
                }
                for df in [-1, 1] {
                    guard let target = Self.offset(square, df, dir) else { continue }
                    if let other = board[target], other.side != side {
                        add(target)
                    } else if target == enPassant {
                        moves.append(Move(from: square, to: target))
                    }
                }
            case .knight, .king:
                let steps = piece.kind == .knight ? Self.knightSteps : Self.kingSteps
                for (df, dr) in steps {
                    guard let target = Self.offset(square, df, dr) else { continue }
                    if board[target]?.side != side { moves.append(Move(from: square, to: target)) }
                }
                if piece.kind == .king { moves += castlingMoves(for: side, king: square) }
            case .bishop, .rook, .queen:
                let directions = piece.kind == .bishop ? Self.diagonal
                    : (piece.kind == .rook ? Self.straight : Self.straight + Self.diagonal)
                for (df, dr) in directions {
                    var current = square
                    while let target = Self.offset(current, df, dr) {
                        if let other = board[target] {
                            if other.side != side { moves.append(Move(from: square, to: target)) }
                            break
                        }
                        moves.append(Move(from: square, to: target))
                        current = target
                    }
                }
            }
        }
        return moves
    }

    private func castlingMoves(for side: Side, king: Int) -> [Move] {
        let home = side == .white ? 4 : 60
        guard king == home, !isAttacked(home, by: side.opposite) else { return [] }
        var moves: [Move] = []
        // King side: squares between free, king does not pass through or land on an attacked square.
        if castling.contains(home + 3), board[home + 1] == nil, board[home + 2] == nil,
           !isAttacked(home + 1, by: side.opposite), !isAttacked(home + 2, by: side.opposite) {
            moves.append(Move(from: home, to: home + 2))
        }
        if castling.contains(home - 4), board[home - 1] == nil, board[home - 2] == nil, board[home - 3] == nil,
           !isAttacked(home - 1, by: side.opposite), !isAttacked(home - 2, by: side.opposite) {
            moves.append(Move(from: home, to: home - 2))
        }
        return moves
    }
}
