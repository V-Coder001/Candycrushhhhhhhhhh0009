/// Block-Puzzle: place three shapes at a time on an 8x8 board. Full rows and columns clear.
/// No timer and no gravity; the game ends when none of the shapes in hand fits anywhere.
public struct BlockPuzzle {
    public static let size = 8

    public struct Cell: Hashable {
        public let row: Int
        public let col: Int

        public init(_ row: Int, _ col: Int) {
            self.row = row
            self.col = col
        }
    }

    public struct Shape: Hashable, Identifiable {
        public let id: Int
        /// Cells relative to the top-left corner of the shape.
        public let cells: [Cell]
        /// Index into the app's block colours.
        public let color: Int

        public var width: Int { (cells.map(\.col).max() ?? 0) + 1 }
        public var height: Int { (cells.map(\.row).max() ?? 0) + 1 }
    }

    public struct Placement: Equatable {
        public let cells: [Cell]
        public let clearedRows: [Int]
        public let clearedCols: [Int]
        public let points: Int
        public var linesCleared: Int { clearedRows.count + clearedCols.count }
    }

    /// Board colours by cell, nil = empty.
    public private(set) var board: [[Int?]]
    public private(set) var hand: [Shape?] = []
    public private(set) var score = 0
    /// Consecutive placements that cleared at least one line.
    public private(set) var streak = 0
    private var nextID = 0
    private var rng: GameRandom

    public init(seed: UInt64) {
        board = Array(repeating: Array(repeating: nil, count: Self.size), count: Self.size)
        rng = GameRandom(seed: seed)
        dealHand()
    }

    /// For tests: a board from text, `#` filled, `.` empty.
    public init(rows: [String], hand: [[Cell]], seed: UInt64 = 1) {
        board = rows.map { line in line.map { $0 == "#" ? 0 : nil } }
        rng = GameRandom(seed: seed)
        self.hand = hand.map { cells in
            defer { nextID += 1 }
            return Shape(id: nextID, cells: cells, color: 0)
        }
    }

    // MARK: Rules

    public func canPlace(_ shape: Shape, row: Int, col: Int) -> Bool {
        shape.cells.allSatisfy { cell in
            let r = row + cell.row, c = col + cell.col
            return r >= 0 && r < Self.size && c >= 0 && c < Self.size && board[r][c] == nil
        }
    }

    public func fitsAnywhere(_ shape: Shape) -> Bool {
        for r in 0..<Self.size {
            for c in 0..<Self.size where canPlace(shape, row: r, col: c) {
                return true
            }
        }
        return false
    }

    public var isOver: Bool {
        !hand.compactMap { $0 }.contains(where: fitsAnywhere)
    }

    /// Places the shape from the hand with its top-left corner at (row, col).
    @discardableResult
    public mutating func place(handIndex: Int, row: Int, col: Int) -> Placement? {
        guard hand.indices.contains(handIndex), let shape = hand[handIndex],
              canPlace(shape, row: row, col: col) else { return nil }
        let cells = shape.cells.map { Cell(row + $0.row, col + $0.col) }
        for cell in cells { board[cell.row][cell.col] = shape.color }
        hand[handIndex] = nil

        let fullRows = (0..<Self.size).filter { r in board[r].allSatisfy { $0 != nil } }
        let fullCols = (0..<Self.size).filter { c in board.allSatisfy { $0[c] != nil } }
        for r in fullRows {
            for c in 0..<Self.size { board[r][c] = nil }
        }
        for c in fullCols {
            for r in 0..<Self.size { board[r][c] = nil }
        }
        let lines = fullRows.count + fullCols.count
        streak = lines > 0 ? streak + 1 : 0
        // One point per block, 10 per line, more for several lines at once and for a streak.
        let points = cells.count + lines * 10 * lines + (lines > 0 ? (streak - 1) * 10 : 0)
        score += points

        if hand.allSatisfy({ $0 == nil }) { dealHand() }
        return Placement(cells: cells, clearedRows: fullRows, clearedCols: fullCols, points: points)
    }

    // MARK: Shapes

    static let catalog: [[Cell]] = {
        func cells(_ rows: [String]) -> [Cell] {
            var result: [Cell] = []
            for (r, line) in rows.enumerated() {
                for (c, ch) in line.enumerated() where ch == "#" { result.append(Cell(r, c)) }
            }
            return result
        }
        return [
            cells(["#"]),
            cells(["##"]), cells(["#", "#"]),
            cells(["###"]), cells(["#", "#", "#"]),
            cells(["####"]), cells(["#", "#", "#", "#"]),
            cells(["#####"]), cells(["#", "#", "#", "#", "#"]),
            cells(["##", "##"]),
            cells(["###", "###", "###"]),
            cells(["##", "#."]), cells(["##", ".#"]), cells(["#.", "##"]), cells([".#", "##"]),
            cells(["###", "#..", "#.."]), cells(["###", "..#", "..#"]),
            cells(["#..", "#..", "###"]), cells(["..#", "..#", "###"]),
            cells(["###", ".#."]), cells([".#.", "###"]), cells(["#.", "##", "#."]), cells([".#", "##", ".#"]),
            cells(["##.", ".##"]), cells([".##", "##."]), cells(["#.", "##", ".#"]), cells([".#", "##", "#."]),
            cells(["#.", "#.", "##"]), cells(["##", "#.", "#."]), cells(["###", "#.."]), cells(["..#", "###"]),
        ]
    }()

    static let colorCount = 7

    /// Three new shapes. Tries to give at least one that fits, so a game never ends on a dealt hand alone.
    private mutating func dealHand() {
        var best: [Shape] = []
        for _ in 0..<12 {
            let shapes = (0..<3).map { _ -> Shape in
                defer { nextID += 1 }
                return Shape(id: nextID, cells: Self.catalog[rng.int(Self.catalog.count)], color: rng.int(Self.colorCount))
            }
            best = shapes
            if shapes.contains(where: fitsAnywhere) { break }
        }
        hand = best
    }
}
