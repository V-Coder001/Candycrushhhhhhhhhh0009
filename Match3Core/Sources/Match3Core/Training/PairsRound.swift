/// Paare finden: cards lie face down, two are turned per attempt, equal motifs stay open.
public struct PairsRound {
    public struct Card: Identifiable, Hashable {
        public let id: Int
        /// Index into the app's list of motifs.
        public let motif: Int
        public var isFaceUp = false
        public var isMatched = false
    }

    public enum FlipResult: Equatable {
        /// Card is already open or the round is over.
        case ignored
        case first
        case match
        /// The two open cards differ; they stay visible until `hideMismatch()` or the next flip.
        case mismatch
    }

    public let level: Int
    public private(set) var cards: [Card]
    public private(set) var attempts = 0
    private var firstPick: Int?
    private var mismatch: (Int, Int)?

    public static func pairCount(level: Int) -> Int {
        SkillLevel.scaled(level, from: 3, to: 12)
    }

    /// Three columns for small rounds, four once there are more than eight cards.
    public var columns: Int { cards.count > 9 ? 4 : 3 }

    public init(level: Int, motifCount: Int, seed: UInt64) {
        self.level = level
        var rng = TrainingRandom(seed: seed)
        let pairs = min(Self.pairCount(level: level), motifCount)
        let motifs = Array(rng.shuffled(Array(0..<motifCount)).prefix(pairs))
        cards = rng.shuffled(motifs + motifs).enumerated().map { Card(id: $0.offset, motif: $0.element) }
    }

    public var pairs: Int { cards.count / 2 }
    public var matchedPairs: Int { cards.filter(\.isMatched).count / 2 }
    public var isComplete: Bool { cards.allSatisfy(\.isMatched) }

    /// 1 when every attempt found a pair, 0.8 at 40 % extra attempts, 0.5 at twice the minimum.
    public var score: Double {
        guard attempts > 0 else { return 0 }
        let extra = Double(attempts - pairs) / Double(2 * pairs)
        return min(1, max(0, 1 - extra))
    }

    public mutating func hideMismatch() {
        guard let (a, b) = mismatch else { return }
        cards[a].isFaceUp = false
        cards[b].isFaceUp = false
        mismatch = nil
    }

    @discardableResult
    public mutating func flip(_ index: Int) -> FlipResult {
        guard cards.indices.contains(index), !isComplete else { return .ignored }
        hideMismatch()
        guard !cards[index].isFaceUp, !cards[index].isMatched else { return .ignored }
        cards[index].isFaceUp = true
        guard let first = firstPick else {
            firstPick = index
            return .first
        }
        firstPick = nil
        attempts += 1
        if cards[first].motif == cards[index].motif {
            cards[first].isMatched = true
            cards[index].isMatched = true
            return .match
        }
        mismatch = (first, index)
        return .mismatch
    }
}
