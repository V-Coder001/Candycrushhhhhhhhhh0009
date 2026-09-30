public struct PlacedPiece: Hashable {
    public var piece: Piece
    public var position: Position

    public init(_ piece: Piece, _ position: Position) {
        self.piece = piece
        self.position = position
    }
}

/// A power-up going off. The renderer uses `kind` to pick the effect and `affected` to aim it.
public struct Activation: Hashable {
    public enum Kind: Hashable {
        case lineHorizontal
        case lineVertical
        case area(radius: Int)
        case colorBomb(CandyColor?)
        case fish(target: Position)
        /// Row and column (striped + striped) or three of each (striped + wrapped).
        case cross(width: Int)
        case wholeBoard
        /// Hammer booster smashing one cell.
        case hammer
    }

    public var origin: Position
    public var kind: Kind
    public var affected: [Position]
}

/// One round of the cascade loop: pop, fall, refill.
public struct CascadeStep {
    /// 1 for the player's move, 2+ for chain reactions.
    public var index: Int
    public var matches: [MatchGroup] = []
    public var activations: [Activation] = []
    /// Candies that changed their special before popping (colour bomb + striped/wrapped).
    public var transformed: [PlacedPiece] = []
    public var cleared: [PlacedPiece] = []
    /// Blockers that took a hit but are still standing (with their new hit count).
    public var damaged: [PlacedPiece] = []
    public var locksBroken: [Position] = []
    public var jellyHit: [Position] = []
    public var created: [PlacedPiece] = []
    /// Wrapped candies waiting for their second explosion.
    public var rearmed: [PlacedPiece] = []
    public var collected: [PlacedPiece] = []
    /// Mixed candies popped in this step.
    public var served: [PlacedPiece] = []
    public var falls: [FallMove] = []
    public var spawns: [Spawn] = []
    public var scoreGained = 0
    /// Moves turned into striped candies at the start of this step (sugar rush only).
    public var movesSpent = 0
    /// Board after this step.
    public var board: Board

    public var isBigExplosion: Bool {
        activations.contains { activation in
            switch activation.kind {
            case .lineHorizontal, .lineVertical, .fish, .hammer: return false
            case .area, .colorBomb, .cross, .wholeBoard: return true
            }
        } || cleared.count >= 12
    }
}

public struct ChocolateSpread: Hashable {
    public var from: Position
    public var to: Position
    public var replaced: Piece
    public var chocolate: Piece
}

public enum ComboWord: String, CaseIterable {
    case sweet = "Sweet!"
    case tasty = "Tasty!"
    case delicious = "Delicious!"
    case divine = "Divine!"

    /// Word for a move with `cascades` steps that removed `cleared` pieces.
    public static func forMove(cascades: Int, cleared: Int) -> ComboWord? {
        switch (cascades, cleared) {
        case (5..., _), (_, 30...): return .divine
        case (4, _), (_, 20...): return .delicious
        case (3, _), (_, 14...): return .tasty
        case (2, _), (_, 9...): return .sweet
        default: return nil
        }
    }
}

public enum GameStatus: Hashable {
    case playing
    case won
    case lost
}

public struct MoveResult {
    public var isValid: Bool
    public var from: Position
    public var to: Position
    public var steps: [CascadeStep] = []
    public var chocolateSpread: ChocolateSpread?
    /// Set when no move was left and the board had to be shuffled.
    public var shuffledBoard: Board?
    public var comboWord: ComboWord?
    /// Victory lap after a won level: leftover specials go off and every move left becomes a
    /// striped candy that fires right away. Played after `steps`.
    public var sugarRush: [CascadeStep] = []
    /// Points earned in the sugar rush.
    public var bonusScore = 0
    public var status: GameStatus
    public var board: Board
}
