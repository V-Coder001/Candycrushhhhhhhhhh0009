/// A connected set of same-coloured candies that pop together.
public struct MatchGroup: Hashable {
    public enum Reward: Hashable {
        case none
        /// Four in a row. The axis is the direction of the run.
        case striped(Axis)
        /// L or T shape.
        case wrapped
        /// 2x2 square.
        case fish
        /// Five in a straight line.
        case colorBomb
    }

    public var positions: Set<Position>
    public var color: CandyColor
    public var longestHorizontal: Int
    public var longestVertical: Int
    public var containsSquare: Bool

    public var reward: Reward {
        let longest = max(longestHorizontal, longestVertical)
        if longest >= 5 { return .colorBomb }
        if longestHorizontal >= 3 && longestVertical >= 3 { return .wrapped }
        if longestHorizontal == 4 { return .striped(.horizontal) }
        if longestVertical == 4 { return .striped(.vertical) }
        if containsSquare { return .fish }
        return .none
    }

    /// The special piece this match creates, if any.
    /// A horizontal run of four creates a candy that clears the column, and vice versa.
    public var rewardKind: PieceKind? {
        switch reward {
        case .none: return nil
        case .striped(.horizontal): return .candy(color, .stripedVertical)
        case .striped(.vertical): return .candy(color, .stripedHorizontal)
        case .wrapped: return .candy(color, .wrapped)
        case .fish: return .candy(color, .fish)
        case .colorBomb: return .colorBomb
        }
    }

    public var sortedPositions: [Position] { positions.sorted() }
}

public enum MatchFinder {
    private struct Shape {
        var color: CandyColor
        var cells: [Position]
        var horizontal = 0
        var vertical = 0
        var square = false
    }

    /// Finds every match on the board: runs of 3+ in a row or column and 2x2 squares.
    /// Mixed candies count as both of their colours, so they can join two lines into one group.
    public static func findMatches(in board: Board) -> [MatchGroup] {
        var shapes: [Shape] = []

        // Collects runs and squares of cells that share a colour key.
        func scan(_ key: (Position) -> CandyColor?) {
            for r in 0..<board.rows {
                var c = 0
                while c < board.columns {
                    guard let color = key(Position(r, c)) else { c += 1; continue }
                    var end = c + 1
                    while end < board.columns, key(Position(r, end)) == color { end += 1 }
                    if end - c >= 3 {
                        shapes.append(Shape(color: color, cells: (c..<end).map { Position(r, $0) },
                                            horizontal: end - c))
                    }
                    c = end
                }
            }
            for c in 0..<board.columns {
                var r = 0
                while r < board.rows {
                    guard let color = key(Position(r, c)) else { r += 1; continue }
                    var end = r + 1
                    while end < board.rows, key(Position(end, c)) == color { end += 1 }
                    if end - r >= 3 {
                        shapes.append(Shape(color: color, cells: (r..<end).map { Position($0, c) },
                                            vertical: end - r))
                    }
                    r = end
                }
            }
            if board.rows > 1 && board.columns > 1 {
                for r in 0..<(board.rows - 1) {
                    for c in 0..<(board.columns - 1) {
                        let square = [Position(r, c), Position(r, c + 1), Position(r + 1, c), Position(r + 1, c + 1)]
                        guard let color = key(square[0]), square.allSatisfy({ key($0) == color }) else { continue }
                        shapes.append(Shape(color: color, cells: square, square: true))
                    }
                }
            }
        }

        let mixes = board.positions.compactMap { p -> PieceKind? in
            guard let kind = board[p]?.kind, kind.isMix else { return nil }
            return kind
        }
        if mixes.isEmpty {
            // Every piece has at most one colour: one pass is enough.
            scan { board.color(at: $0) }
        } else {
            // Mixed candies count as both colours, so each of their colours gets its own pass.
            let mixColors = Set(mixes.flatMap(\.colors))
            scan { p in board.color(at: p).flatMap { mixColors.contains($0) ? nil : $0 } }
            for color in CandyColor.allCases where mixColors.contains(color) {
                scan { board.has(color, at: $0) ? color : nil }
            }
        }

        // Merge shapes that share a cell into one group.
        var groups: [MatchGroup] = []
        for shape in shapes {
            var merged = MatchGroup(positions: Set(shape.cells), color: shape.color,
                                    longestHorizontal: shape.horizontal,
                                    longestVertical: shape.vertical,
                                    containsSquare: shape.square)
            groups.removeAll { group in
                guard !group.positions.isDisjoint(with: merged.positions) else { return false }
                merged.positions.formUnion(group.positions)
                merged.longestHorizontal = max(merged.longestHorizontal, group.longestHorizontal)
                merged.longestVertical = max(merged.longestVertical, group.longestVertical)
                merged.containsSquare = merged.containsSquare || group.containsSquare
                return true
            }
            groups.append(merged)
        }
        return groups.sorted { $0.sortedPositions[0] < $1.sortedPositions[0] }
    }

    /// Fast check: is the piece at `p` part of any match?
    public static func hasMatch(at p: Position, in board: Board) -> Bool {
        guard let kind = board[p]?.kind else { return false }
        return kind.colors.contains { hasMatch(at: p, color: $0, in: board) }
    }

    private static func hasMatch(at p: Position, color: CandyColor, in board: Board) -> Bool {
        func same(_ q: Position) -> Bool { board.has(color, at: q) }

        var horizontal = 1
        var q = p.left
        while same(q) { horizontal += 1; q = q.left }
        q = p.right
        while same(q) { horizontal += 1; q = q.right }
        if horizontal >= 3 { return true }

        var vertical = 1
        q = p.up
        while same(q) { vertical += 1; q = q.up }
        q = p.down
        while same(q) { vertical += 1; q = q.down }
        if vertical >= 3 { return true }

        for dr in [-1, 0] {
            for dc in [-1, 0] {
                let origin = Position(p.row + dr, p.col + dc)
                let square = [origin, origin.right, origin.down, origin.down.right]
                if square.allSatisfy(same) { return true }
            }
        }
        return false
    }

    public static func hasAnyMatch(in board: Board) -> Bool {
        board.positions.contains { hasMatch(at: $0, in: board) }
    }

    /// Swapping these two pieces triggers a special combination (no regular match needed).
    public static func isCombo(_ a: PieceKind, _ b: PieceKind) -> Bool {
        switch (a, b) {
        case (.colorBomb, .colorBomb), (.colorBomb, .candy), (.candy, .colorBomb):
            return true
        case let (.candy(_, s1), .candy(_, s2)):
            return s1.isCombinable && s2.isCombinable
        default:
            return false
        }
    }

    /// Would swapping `a` and `b` be a legal move?
    public static func isValidSwap(_ a: Position, _ b: Position, in board: Board) -> Bool {
        guard a.isAdjacent(to: b), board.isSwappable(a), board.isSwappable(b),
              let pa = board[a], let pb = board[b] else { return false }
        if isCombo(pa.kind, pb.kind) { return true }
        var copy = board
        copy[a] = pb
        copy[b] = pa
        return hasMatch(at: a, in: copy) || hasMatch(at: b, in: copy)
    }

    /// First legal move, scanning row by row. Nil means the board needs a shuffle.
    public static func findPossibleMove(in board: Board) -> (Position, Position)? {
        for p in board.positions {
            for q in [p.right, p.down] where isValidSwap(p, q, in: board) {
                return (p, q)
            }
        }
        return nil
    }
}
