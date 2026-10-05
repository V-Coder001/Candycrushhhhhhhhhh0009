/// A playing card. Rank 1 is the ace, 11 jack, 12 queen, 13 king.
public struct PlayingCard: Hashable, Identifiable {
    public enum Suit: Int, CaseIterable {
        case hearts, diamonds, clubs, spades

        public var isRed: Bool { self == .hearts || self == .diamonds }
        public var symbol: String {
            switch self {
            case .hearts: return "♥"
            case .diamonds: return "♦"
            case .clubs: return "♣"
            case .spades: return "♠"
            }
        }
    }

    public let suit: Suit
    public let rank: Int
    public var faceUp = false

    public var id: Int { suit.rawValue * 13 + rank }

    public var rankText: String {
        switch rank {
        case 1: return "A"
        case 11: return "B"
        case 12: return "D"
        case 13: return "K"
        default: return "\(rank)"
        }
    }

    public init(suit: Suit, rank: Int, faceUp: Bool = false) {
        self.suit = suit
        self.rank = rank
        self.faceUp = faceUp
    }
}

/// Klondike solitaire, drawing one card at a time. Players tap a card and it goes to the best place.
public struct Klondike {
    public enum Pile: Hashable {
        case stock
        case waste
        case foundation(Int)
        case tableau(Int)
    }

    public private(set) var stock: [PlayingCard] = []
    public private(set) var waste: [PlayingCard] = []
    /// Four piles, built up from ace to king in one suit.
    public private(set) var foundations: [[PlayingCard]] = Array(repeating: [], count: 4)
    /// Seven columns, built down in alternating colours.
    public private(set) var tableau: [[PlayingCard]] = Array(repeating: [], count: 7)
    public private(set) var moves = 0
    private var history: [Snapshot] = []

    private struct Snapshot {
        var stock, waste: [PlayingCard]
        var foundations, tableau: [[PlayingCard]]
        var moves: Int
    }

    public init(seed: UInt64) {
        var rng = GameRandom(seed: seed)
        var deck = rng.shuffled(PlayingCard.Suit.allCases.flatMap { suit in
            (1...13).map { PlayingCard(suit: suit, rank: $0) }
        })
        for column in 0..<7 {
            for row in 0...column {
                var card = deck.removeLast()
                card.faceUp = row == column
                tableau[column].append(card)
            }
        }
        stock = deck
    }

    /// For tests: a given layout.
    public init(tableau: [[PlayingCard]], foundations: [[PlayingCard]] = Array(repeating: [], count: 4),
                stock: [PlayingCard] = [], waste: [PlayingCard] = []) {
        self.tableau = tableau
        self.foundations = foundations
        self.stock = stock
        self.waste = waste
    }

    public var isWon: Bool { foundations.allSatisfy { $0.count == 13 } }
    public var canUndo: Bool { !history.isEmpty }

    /// Everything is face up and nothing waits in stock or waste: the rest plays itself.
    public var canAutoFinish: Bool {
        stock.isEmpty && waste.isEmpty && tableau.allSatisfy { $0.allSatisfy(\.faceUp) } && !isWon
    }

    // MARK: Rules

    public func canPlaceOnFoundation(_ card: PlayingCard, _ index: Int) -> Bool {
        let pile = foundations[index]
        guard let top = pile.last else { return card.rank == 1 }
        return top.suit == card.suit && card.rank == top.rank + 1
    }

    public func canPlaceOnTableau(_ card: PlayingCard, _ index: Int) -> Bool {
        guard let top = tableau[index].last else { return card.rank == 13 }
        return top.faceUp && top.suit.isRed != card.suit.isRed && card.rank == top.rank - 1
    }

    /// Turns over the next stock card, or turns the waste back over when the stock is empty.
    public mutating func draw() {
        guard !stock.isEmpty || !waste.isEmpty else { return }
        save()
        if stock.isEmpty {
            stock = waste.reversed().map { card in
                var card = card
                card.faceUp = false
                return card
            }
            waste = []
        } else {
            var card = stock.removeLast()
            card.faceUp = true
            waste.append(card)
        }
        moves += 1
    }

    /// Moves the tapped card (with the cards on top of it in the tableau) to the best legal place:
    /// a foundation first for single cards, then a column. Returns the target, or nil if nothing fits.
    @discardableResult
    public mutating func autoMove(from pile: Pile, index: Int? = nil) -> Pile? {
        switch pile {
        case .stock:
            draw()
            return .waste
        case .waste:
            guard let card = waste.last else { return nil }
            guard let target = target(for: card, single: true, excluding: nil) else { return nil }
            save()
            waste.removeLast()
            put([card], on: target)
            return target
        case let .foundation(f):
            guard let card = foundations[f].last,
                  let column = (0..<7).first(where: { canPlaceOnTableau(card, $0) }) else { return nil }
            save()
            foundations[f].removeLast()
            put([card], on: .tableau(column))
            return .tableau(column)
        case let .tableau(t):
            let column = tableau[t]
            let start = index ?? column.count - 1
            guard column.indices.contains(start), column[start].faceUp else { return nil }
            let cards = Array(column[start...])
            guard let target = target(for: cards[0], single: cards.count == 1, excluding: t) else { return nil }
            save()
            tableau[t].removeSubrange(start...)
            put(cards, on: target)
            revealTop(t)
            return target
        }
    }

    /// Moves every card that can go to a foundation, until none can. Used to finish a solved game.
    public mutating func autoFinish() {
        var progress = true
        while progress {
            progress = false
            if let card = waste.last, let f = (0..<4).first(where: { canPlaceOnFoundation(card, $0) }) {
                save()
                waste.removeLast()
                put([card], on: .foundation(f))
                progress = true
            }
            for t in 0..<7 {
                if let card = tableau[t].last, card.faceUp,
                   let f = (0..<4).first(where: { canPlaceOnFoundation(card, $0) }) {
                    save()
                    tableau[t].removeLast()
                    put([card], on: .foundation(f))
                    revealTop(t)
                    progress = true
                }
            }
        }
    }

    public mutating func undo() {
        guard let last = history.popLast() else { return }
        stock = last.stock
        waste = last.waste
        foundations = last.foundations
        tableau = last.tableau
        moves = last.moves
    }

    // MARK: Helpers

    private func target(for card: PlayingCard, single: Bool, excluding column: Int?) -> Pile? {
        if single, let f = (0..<4).first(where: { canPlaceOnFoundation(card, $0) }) {
            return .foundation(f)
        }
        // Prefer a column that already has cards; an empty one only for kings that are not already alone.
        let columns = (0..<7).filter { $0 != column && canPlaceOnTableau(card, $0) }
        if let used = columns.first(where: { !tableau[$0].isEmpty }) { return .tableau(used) }
        if let empty = columns.first {
            if let column, tableau[column].first == card { return nil }
            return .tableau(empty)
        }
        return nil
    }

    private mutating func put(_ cards: [PlayingCard], on pile: Pile) {
        switch pile {
        case let .foundation(f): foundations[f] += cards
        case let .tableau(t): tableau[t] += cards
        case .waste: waste += cards
        case .stock: stock += cards
        }
        moves += 1
    }

    private mutating func revealTop(_ column: Int) {
        guard let last = tableau[column].indices.last else { return }
        tableau[column][last].faceUp = true
    }

    private mutating func save() {
        history.append(Snapshot(stock: stock, waste: waste, foundations: foundations, tableau: tableau, moves: moves))
        if history.count > 200 { history.removeFirst() }
    }
}
