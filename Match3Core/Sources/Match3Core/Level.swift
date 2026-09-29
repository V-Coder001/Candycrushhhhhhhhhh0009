public enum Goal: Hashable, Codable {
    /// Reach this many points.
    case score(Int)
    /// Remove every layer of jelly.
    case clearJelly
    /// Bring this many ingredients to the bottom.
    case collectIngredients(Int)
    /// Remove all chocolate.
    case clearChocolate
}

public struct GoalProgress: Hashable {
    public var goal: Goal
    /// Score reached, jelly removed, ingredients collected or chocolate removed.
    public var current: Int
    public var target: Int

    public var isMet: Bool { current >= target }
    public var remaining: Int { max(0, target - current) }

    public static func evaluate(goals: [Goal], score: Int, board: Board, collected: Int,
                                initialJelly: Int, initialChocolate: Int) -> [GoalProgress] {
        goals.map { goal in
            switch goal {
            case let .score(target):
                return GoalProgress(goal: goal, current: score, target: target)
            case .clearJelly:
                return GoalProgress(goal: goal, current: initialJelly - board.jellyRemaining, target: initialJelly)
            case let .collectIngredients(count):
                return GoalProgress(goal: goal, current: collected, target: count)
            case .clearChocolate:
                let left = board.count { $0.isChocolate }
                // Chocolate can grow beyond its start size, so only an empty board counts as done.
                let current = left == 0 ? initialChocolate : max(0, min(initialChocolate - 1, initialChocolate - left))
                return GoalProgress(goal: goal, current: current, target: initialChocolate)
            }
        }
    }
}

/// A level definition. The layout uses one character per cell:
///
/// `.` candy, `#` hole, `j` candy on jelly, `J` candy on double jelly, `l` locked candy,
/// `k` locked candy on jelly, `c` chocolate, `b` blocker (2 hits), `B` blocker (3 hits),
/// `i` ingredient (cherry), `h` ingredient (hazelnut).
public struct Level: Hashable, Codable, Identifiable {
    public var id: Int
    public var name: String
    public var moves: Int
    /// Number of candy colours in play (3...6).
    public var colors: Int
    public var goals: [Goal]
    /// Score thresholds for one, two and three stars.
    public var starScores: [Int]
    public var layout: [String]
    public var maxIngredientsOnBoard: Int

    public init(id: Int, name: String, moves: Int, colors: Int = 5, goals: [Goal], starScores: [Int],
                layout: [String], maxIngredientsOnBoard: Int = 1) {
        self.id = id
        self.name = name
        self.moves = moves
        self.colors = colors
        self.goals = goals
        self.starScores = starScores
        self.layout = layout
        self.maxIngredientsOnBoard = maxIngredientsOnBoard
    }

    public var rows: Int { layout.count }
    public var columns: Int { layout.map(\.count).max() ?? 0 }

    public var palette: [CandyColor] { Array(CandyColor.allCases.prefix(max(3, min(colors, 6)))) }

    /// Score-only levels run until the last move, like in the classic game, so there is room for
    /// three stars. Every other level ends as soon as its goals are met and the leftover moves
    /// turn into a sugar rush.
    public var playsAllMoves: Bool {
        goals.allSatisfy { goal in
            if case .score = goal { return true }
            return false
        }
    }

    public var ingredientsRequired: Int {
        goals.reduce(0) { total, goal in
            if case let .collectIngredients(count) = goal { return total + count }
            return total
        }
    }

    /// Cells and fixed pieces from the layout. Positions in `candySlots` still need a random candy.
    func skeleton() -> (board: Board, candySlots: [Position]) {
        var board = Board(rows: rows, columns: columns)
        var slots: [Position] = []
        for (r, line) in layout.enumerated() {
            let chars = Array(line)
            for c in 0..<columns {
                let p = Position(r, c)
                let ch: Character = c < chars.count ? chars[c] : "#"
                var cell = Cell()
                var kind: PieceKind?
                switch ch {
                case "#": cell.isHole = true
                case "j": cell.jelly = 1
                case "J": cell.jelly = 2
                case "l": cell.locked = true
                case "k": cell.locked = true; cell.jelly = 1
                case "c": kind = .chocolate
                case "b": kind = .blocker(hits: 2)
                case "B": kind = .blocker(hits: 3)
                case "i": kind = .ingredient(.cherry)
                case "h": kind = .ingredient(.hazelnut)
                default: break
                }
                board.setCell(p, cell)
                if let kind {
                    board[p] = board.makePiece(kind)
                } else if !cell.isHole {
                    slots.append(p)
                }
            }
        }
        return (board, slots)
    }
}
