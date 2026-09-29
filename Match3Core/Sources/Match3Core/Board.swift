/// Static properties of a cell that live underneath the piece.
public struct Cell: Hashable {
    /// Not part of the board (used for level shapes). Pieces fall through holes.
    public var isHole: Bool
    /// Layers of jelly under the piece (0, 1 or 2).
    public var jelly: Int
    /// Lock / grid: the piece can neither be swapped nor fall. A hit breaks the lock.
    public var locked: Bool

    public init(isHole: Bool = false, jelly: Int = 0, locked: Bool = false) {
        self.isHole = isHole
        self.jelly = jelly
        self.locked = locked
    }
}

public struct FallMove: Hashable {
    public var pieceID: Int
    public var from: Position
    public var to: Position
}

public struct Spawn: Hashable {
    public var piece: Piece
    public var position: Position
    /// Row above the board the piece starts falling from (negative).
    public var startRow: Int
    /// Column it spawned in (differs from `position.col` if it slid diagonally afterwards).
    public var startColumn: Int
}

/// The 2D grid. Value type, so every cascade step can carry a cheap snapshot for the renderer.
public struct Board: Hashable {
    public let rows: Int
    public let columns: Int
    public internal(set) var cells: [Cell]
    var pieces: [Piece?]
    var nextPieceID = 1

    public init(rows: Int, columns: Int) {
        precondition(rows > 0 && columns > 0)
        self.rows = rows
        self.columns = columns
        cells = Array(repeating: Cell(), count: rows * columns)
        pieces = Array(repeating: nil, count: rows * columns)
    }

    @inline(__always) func index(_ p: Position) -> Int { p.row * columns + p.col }

    public func contains(_ p: Position) -> Bool {
        p.row >= 0 && p.row < rows && p.col >= 0 && p.col < columns
    }

    /// Inside the board and not a hole.
    public func isPlayable(_ p: Position) -> Bool {
        contains(p) && !cells[index(p)].isHole
    }

    public subscript(_ p: Position) -> Piece? {
        get { contains(p) ? pieces[index(p)] : nil }
        set {
            precondition(contains(p), "position \(p) outside board")
            pieces[index(p)] = newValue
        }
    }

    public func cell(_ p: Position) -> Cell {
        contains(p) ? cells[index(p)] : Cell(isHole: true)
    }

    mutating func setCell(_ p: Position, _ cell: Cell) {
        cells[index(p)] = cell
    }

    /// All playable positions in row-major order.
    public var positions: [Position] {
        var result: [Position] = []
        result.reserveCapacity(rows * columns)
        for r in 0..<rows {
            for c in 0..<columns where !cells[r * columns + c].isHole {
                result.append(Position(r, c))
            }
        }
        return result
    }

    public func color(at p: Position) -> CandyColor? {
        self[p]?.kind.color
    }

    /// A piece that can be swapped by the player.
    public func isSwappable(_ p: Position) -> Bool {
        guard isPlayable(p), let piece = self[p] else { return false }
        return piece.kind.isMovable && !cell(p).locked
    }

    func canFall(_ p: Position) -> Bool {
        isSwappable(p)
    }

    public var jellyRemaining: Int { cells.reduce(0) { $0 + ($1.isHole ? 0 : $1.jelly) } }

    public func count(where predicate: (PieceKind) -> Bool) -> Int {
        pieces.reduce(0) { $0 + (($1.map { predicate($0.kind) } ?? false) ? 1 : 0) }
    }

    public func positions(where predicate: (PieceKind) -> Bool) -> [Position] {
        positions.filter { p in self[p].map { predicate($0.kind) } ?? false }
    }

    public var allPieces: [(Position, Piece)] {
        positions.compactMap { p in self[p].map { (p, $0) } }
    }

    mutating func makePiece(_ kind: PieceKind) -> Piece {
        defer { nextPieceID += 1 }
        return Piece(id: nextPieceID, kind: kind)
    }

    /// Bottom-most playable cell of a column (ingredients leave the board there).
    public func exitRow(column c: Int) -> Int? {
        stride(from: rows - 1, through: 0, by: -1).first { isPlayable(Position($0, c)) }
    }

    // MARK: Gravity

    /// Lets pieces fall, slides them diagonally around blocked cells and spawns new pieces
    /// in columns that are open to the top. Returns the merged movement of every piece.
    mutating func collapse(spawn: (inout Board, Position) -> Piece) -> (falls: [FallMove], spawns: [Spawn]) {
        var moveOrder: [Int] = []
        var moves: [Int: FallMove] = [:]
        var spawnOrder: [Int] = []
        var spawns: [Int: Spawn] = [:]
        var spawnedInColumn: [Int: Int] = [:]

        func move(_ from: Position, _ to: Position) {
            guard let piece = self[from] else { return }
            self[to] = piece
            self[from] = nil
            if spawns[piece.id] != nil {
                spawns[piece.id]!.position = to
            } else if moves[piece.id] != nil {
                moves[piece.id]!.to = to
            } else {
                moves[piece.id] = FallMove(pieceID: piece.id, from: from, to: to)
                moveOrder.append(piece.id)
            }
        }

        var changed = true
        var guardCounter = 0
        while changed && guardCounter < 10_000 {
            changed = false
            guardCounter += 1

            // Straight down.
            for c in 0..<columns {
                for r in stride(from: rows - 1, through: 0, by: -1) {
                    let p = Position(r, c)
                    guard isPlayable(p), self[p] == nil else { continue }
                    var rr = r - 1
                    var source: Position?
                    var blocked = false
                    while rr >= 0 {
                        let q = Position(rr, c)
                        if isPlayable(q), self[q] != nil {
                            if canFall(q) { source = q } else { blocked = true }
                            break
                        }
                        rr -= 1
                    }
                    if let source {
                        move(source, p)
                        changed = true
                    } else if !blocked {
                        let piece = spawn(&self, p)
                        self[p] = piece
                        spawnedInColumn[c, default: 0] += 1
                        spawns[piece.id] = Spawn(piece: piece, position: p, startRow: -spawnedInColumn[c]!,
                                                 startColumn: c)
                        spawnOrder.append(piece.id)
                        changed = true
                    }
                }
            }
            if changed { continue }

            // Diagonal slide into cells that cannot be reached from above.
            search: for r in stride(from: rows - 1, through: 1, by: -1) {
                for c in 0..<columns {
                    let p = Position(r, c)
                    guard isPlayable(p), self[p] == nil else { continue }
                    for dc in [-1, 1] {
                        let q = Position(r - 1, c + dc)
                        if isPlayable(q), canFall(q) {
                            move(q, p)
                            changed = true
                            break search
                        }
                    }
                }
            }
        }

        // Spawns fall in stacked above their column: the lowest target starts closest to the board.
        let spawnList: [Spawn] = spawnOrder.map { id in
            var s = spawns[id]!
            s.piece = self[s.position] ?? s.piece
            return s
        }
        return (moveOrder.map { moves[$0]! }, spawnList)
    }

    // MARK: Text format (tests & debugging)

    /// Parses a whitespace separated grid.
    ///
    /// Tokens: `R O Y G B P` colours, suffix `-` striped horizontal, `|` striped vertical,
    /// `@` wrapped, `!` wrapped (armed), `>` fish. `*` colour bomb, `C` chocolate, `X2` blocker with 2 hits,
    /// `I` cherry, `H` hazelnut, `_` empty, `#` hole.
    /// Lower-case prefixes add overlays: `j` jelly, `k` double jelly, `l` lock. Example: `jlR-`.
    public static func parse(_ lines: [String]) -> Board {
        let grid = lines.map { $0.split(whereSeparator: { $0 == " " }).map(String.init) }
        let columns = grid.map(\.count).max() ?? 0
        var board = Board(rows: grid.count, columns: columns)
        for (r, line) in grid.enumerated() {
            for (c, token) in line.enumerated() {
                let p = Position(r, c)
                var cell = Cell()
                var body = Substring(token)
                while let first = body.first, first.isLowercase {
                    switch first {
                    case "j": cell.jelly = 1
                    case "k": cell.jelly = 2
                    case "l": cell.locked = true
                    default: preconditionFailure("unknown overlay \(first) in \(token)")
                    }
                    body = body.dropFirst()
                }
                guard let head = body.first else { preconditionFailure("empty token") }
                var kind: PieceKind?
                switch head {
                case "#": cell.isHole = true
                case "_": kind = nil
                case "*": kind = .colorBomb
                case "C": kind = .chocolate
                case "X": kind = .blocker(hits: Int(body.dropFirst()) ?? 1)
                case "I": kind = .ingredient(.cherry)
                case "H": kind = .ingredient(.hazelnut)
                default:
                    guard let color = CandyColor(token: head) else { preconditionFailure("unknown token \(token)") }
                    var special = Special.none
                    switch body.dropFirst().first {
                    case "-": special = .stripedHorizontal
                    case "|": special = .stripedVertical
                    case "@": special = .wrapped
                    case "!": special = .wrappedArmed
                    case ">": special = .fish
                    default: break
                    }
                    kind = .candy(color, special)
                }
                board.setCell(p, cell)
                if let kind { board[p] = board.makePiece(kind) }
            }
        }
        return board
    }

    public var textRows: [String] {
        (0..<rows).map { r in
            (0..<columns).map { c -> String in
                let p = Position(r, c)
                let cell = self.cell(p)
                if cell.isHole { return "#" }
                var prefix = ""
                if cell.jelly == 1 { prefix += "j" }
                if cell.jelly >= 2 { prefix += "k" }
                if cell.locked { prefix += "l" }
                guard let piece = self[p] else { return prefix + "_" }
                switch piece.kind {
                case .colorBomb: return prefix + "*"
                case .chocolate: return prefix + "C"
                case let .blocker(hits): return prefix + "X\(hits)"
                case .ingredient(.cherry): return prefix + "I"
                case .ingredient(.hazelnut): return prefix + "H"
                case let .candy(color, special):
                    let suffix: String
                    switch special {
                    case .none: suffix = ""
                    case .stripedHorizontal: suffix = "-"
                    case .stripedVertical: suffix = "|"
                    case .wrapped: suffix = "@"
                    case .wrappedArmed: suffix = "!"
                    case .fish: suffix = ">"
                    }
                    return prefix + String(color.token) + suffix
                }
            }.joined(separator: " ")
        }
    }
}

extension Board: CustomStringConvertible {
    public var description: String { textRows.joined(separator: "\n") }
}
