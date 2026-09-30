import UIKit

/// Helpers the player can spend before or during a level.
enum Booster: String, CaseIterable, Identifiable {
    /// Smashes one cell of the player's choice.
    case hammer
    /// Five more moves: at the start, during play or after running out.
    case extraMoves
    /// Mixes the board into a fresh one.
    case colorMixer

    var id: String { rawValue }

    static let extraMovesAmount = 5
    /// Every player starts with this many of each.
    static let starterCount = 3

    var title: String {
        switch self {
        case .hammer: return "Hammer"
        case .extraMoves: return "Extra-Züge"
        case .colorMixer: return "Farbmischer"
        }
    }

    var symbol: String {
        switch self {
        case .hammer: return "hammer.fill"
        case .extraMoves: return "plus.circle.fill"
        case .colorMixer: return "shuffle"
        }
    }

    var color: UIColor {
        switch self {
        case .hammer: return Theme.candy(.orange)
        case .extraMoves: return Theme.candy(.green)
        case .colorMixer: return Theme.candy(.purple)
        }
    }

    var explanation: String {
        switch self {
        case .hammer: return "Zerschlägt ein Feld deiner Wahl: Bonbon, Gitter oder Hindernis."
        case .extraMoves: return "+\(Booster.extraMovesAmount) Züge, vor dem Start oder mitten im Level."
        case .colorMixer: return "Mischt alle Bonbons auf dem Brett neu."
        }
    }

    /// Reward for beating a level for the first time: the three kinds take turns.
    static func reward(forLevel id: Int) -> Booster {
        allCases[id % allCases.count]
    }
}
