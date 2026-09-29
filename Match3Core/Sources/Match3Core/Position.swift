/// A cell coordinate on the board. Row 0 is the top row; gravity pulls towards higher rows.
public struct Position: Hashable, Comparable, Codable, CustomStringConvertible {
    public var row: Int
    public var col: Int

    public init(_ row: Int, _ col: Int) {
        self.row = row
        self.col = col
    }

    public init(row: Int, col: Int) {
        self.init(row, col)
    }

    public static func < (lhs: Position, rhs: Position) -> Bool {
        (lhs.row, lhs.col) < (rhs.row, rhs.col)
    }

    public var up: Position { Position(row - 1, col) }
    public var down: Position { Position(row + 1, col) }
    public var left: Position { Position(row, col - 1) }
    public var right: Position { Position(row, col + 1) }

    public var neighbors: [Position] { [up, down, left, right] }

    public func isAdjacent(to other: Position) -> Bool {
        abs(row - other.row) + abs(col - other.col) == 1
    }

    public var description: String { "(\(row),\(col))" }
}

public enum Axis: String, Hashable, Codable {
    case horizontal
    case vertical
}
