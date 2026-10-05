/// 2048: slide all tiles in one direction, equal neighbours merge into their sum.
public struct Twenty48 {
    public enum Direction: CaseIterable {
        case up, down, left, right
    }

    public struct Tile: Identifiable, Hashable {
        public let id: Int
        public var value: Int
        public var row: Int
        public var col: Int
        /// The tile grew in the last move (for a little pop animation).
        public var merged = false
    }

    public static let size = 4
    public static let goal = 2048

    public private(set) var tiles: [Tile] = []
    public private(set) var score = 0
    /// Set once a 2048 tile appears; playing on is allowed.
    public private(set) var reachedGoal = false
    private var nextID = 0
    private var rng: GameRandom

    public init(seed: UInt64) {
        rng = GameRandom(seed: seed)
        spawn()
        spawn()
    }

    /// For tests: a fixed grid, 0 = empty.
    public init(grid: [[Int]], seed: UInt64 = 1) {
        rng = GameRandom(seed: seed)
        for (r, line) in grid.enumerated() {
            for (c, value) in line.enumerated() where value > 0 {
                tiles.append(Tile(id: nextID, value: value, row: r, col: c))
                nextID += 1
            }
        }
    }

    public var grid: [[Int]] {
        var grid = Array(repeating: Array(repeating: 0, count: Self.size), count: Self.size)
        for tile in tiles { grid[tile.row][tile.col] = tile.value }
        return grid
    }

    public var best: Int { tiles.map(\.value).max() ?? 0 }

    public var isOver: Bool {
        guard tiles.count == Self.size * Self.size else { return false }
        let g = grid
        for r in 0..<Self.size {
            for c in 0..<Self.size {
                if c + 1 < Self.size, g[r][c] == g[r][c + 1] { return false }
                if r + 1 < Self.size, g[r][c] == g[r + 1][c] { return false }
            }
        }
        return true
    }

    /// Slides every line towards `direction`. Returns false (and changes nothing) if no tile could move.
    @discardableResult
    public mutating func move(_ direction: Direction) -> Bool {
        var moved = false
        var result: [Tile] = []
        for line in 0..<Self.size {
            // Cells of this line, ordered from the side the tiles move towards.
            let cells: [(Int, Int)] = (0..<Self.size).map { i in
                switch direction {
                case .left: return (line, i)
                case .right: return (line, Self.size - 1 - i)
                case .up: return (i, line)
                case .down: return (Self.size - 1 - i, line)
                }
            }
            let lineTiles = cells.compactMap { cell in tiles.first { $0.row == cell.0 && $0.col == cell.1 } }
            var placed: [Tile] = []
            var canMerge = true
            for var tile in lineTiles {
                tile.merged = false
                if canMerge, let last = placed.last, last.value == tile.value {
                    placed[placed.count - 1].value *= 2
                    placed[placed.count - 1].merged = true
                    score += last.value * 2
                    if last.value * 2 >= Self.goal { reachedGoal = true }
                    canMerge = false
                    moved = true
                    continue
                }
                canMerge = true
                placed.append(tile)
            }
            for (i, var tile) in placed.enumerated() {
                let target = cells[i]
                if tile.row != target.0 || tile.col != target.1 { moved = true }
                tile.row = target.0
                tile.col = target.1
                result.append(tile)
            }
        }
        guard moved else { return false }
        tiles = result
        spawn()
        return true
    }

    /// A new 2 (sometimes a 4) on a random empty cell.
    private mutating func spawn() {
        var empty: [(Int, Int)] = []
        for r in 0..<Self.size {
            for c in 0..<Self.size where !tiles.contains(where: { $0.row == r && $0.col == c }) {
                empty.append((r, c))
            }
        }
        guard !empty.isEmpty else { return }
        let cell = empty[rng.int(empty.count)]
        tiles.append(Tile(id: nextID, value: rng.int(10) == 0 ? 4 : 2, row: cell.0, col: cell.1))
        nextID += 1
    }
}

/// SplitMix64 helpers for the card and puzzle games, so deals can be replayed in tests.
struct GameRandom {
    private var generator: SeededGenerator

    init(seed: UInt64) {
        generator = SeededGenerator(seed: seed)
    }

    mutating func int(_ upperBound: Int) -> Int {
        Int(generator.next() % UInt64(upperBound))
    }

    mutating func shuffled<T>(_ items: [T]) -> [T] {
        var result = items
        guard result.count > 1 else { return result }
        for i in stride(from: result.count - 1, to: 0, by: -1) {
            result.swapAt(i, int(i + 1))
        }
        return result
    }
}
