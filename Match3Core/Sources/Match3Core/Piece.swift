public enum CandyColor: Int, CaseIterable, Hashable, Codable {
    case red, orange, yellow, green, blue, purple

    /// Single-letter token used by `Board.parse` and debug output.
    public var token: Character {
        switch self {
        case .red: return "R"
        case .orange: return "O"
        case .yellow: return "Y"
        case .green: return "G"
        case .blue: return "B"
        case .purple: return "P"
        }
    }

    public init?(token: Character) {
        guard let match = CandyColor.allCases.first(where: { $0.token == token }) else { return nil }
        self = match
    }
}

/// Power-ups a regular candy can carry.
public enum Special: String, Hashable, Codable {
    case none
    /// Clears its whole row.
    case stripedHorizontal
    /// Clears its whole column.
    case stripedVertical
    /// Explodes in a 3x3 area, then once more after falling.
    case wrapped
    /// A wrapped candy that already exploded once and waits for its second blast.
    case wrappedArmed
    /// Flies to an obstacle or goal cell and hits it.
    case fish

    public var isStriped: Bool { self == .stripedHorizontal || self == .stripedVertical }

    /// Can be combined with another special by swapping.
    public var isCombinable: Bool {
        switch self {
        case .stripedHorizontal, .stripedVertical, .wrapped, .fish: return true
        case .none, .wrappedArmed: return false
        }
    }
}

public enum Ingredient: String, Hashable, Codable, CaseIterable {
    case cherry
    case hazelnut
}

public enum PieceKind: Hashable {
    case candy(CandyColor, Special)
    /// Colour bomb (chocolate sprinkle ball): clears every candy of one colour.
    case colorBomb
    /// Must be brought down to the bottom of the board.
    case ingredient(Ingredient)
    /// Spreads each turn in which no chocolate was destroyed.
    case chocolate
    /// Blockade that needs several hits.
    case blocker(hits: Int)
    /// Two-tone mixed candy, made where matches of two colours touch. It matches with either colour.
    case mix(CandyColor, CandyColor)

    /// A mixed candy with its colours in a fixed order, so red + yellow and yellow + red are the same sort.
    public static func mixed(_ a: CandyColor, _ b: CandyColor) -> PieceKind {
        a.rawValue <= b.rawValue ? .mix(a, b) : .mix(b, a)
    }

    public static func plain(_ color: CandyColor) -> PieceKind { .candy(color, .none) }

    public var color: CandyColor? {
        if case let .candy(color, _) = self { return color }
        return nil
    }

    public var special: Special {
        if case let .candy(_, special) = self { return special }
        return .none
    }

    /// Every colour this piece counts as when looking for matches.
    public var colors: [CandyColor] {
        switch self {
        case let .candy(color, _): return [color]
        case let .mix(a, b): return [a, b]
        default: return []
        }
    }

    public func matches(_ color: CandyColor) -> Bool {
        switch self {
        case let .candy(c, _): return c == color
        case let .mix(a, b): return a == color || b == color
        default: return false
        }
    }

    public var isMix: Bool {
        if case .mix = self { return true }
        return false
    }

    /// Candy, colour bomb, ingredients and mixed candies can be swapped and fall down.
    public var isMovable: Bool {
        switch self {
        case .candy, .colorBomb, .ingredient, .mix: return true
        case .chocolate, .blocker: return false
        }
    }

    public var isObstacle: Bool {
        switch self {
        case .chocolate, .blocker: return true
        default: return false
        }
    }

    public var isIngredient: Bool {
        if case .ingredient = self { return true }
        return false
    }

    public var isChocolate: Bool { self == .chocolate }

    public var isPlainCandy: Bool {
        if case .candy(_, .none) = self { return true }
        return false
    }
}

/// A piece on the board. The id is stable while the piece moves, so the renderer can animate it.
public struct Piece: Hashable, Identifiable {
    public let id: Int
    public var kind: PieceKind

    public init(id: Int, kind: PieceKind) {
        self.id = id
        self.kind = kind
    }
}
