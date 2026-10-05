/// The brain games of Klarkopf. The logic lives here so it can be tested without the app.
public enum BrainGame: String, CaseIterable, Codable, Identifiable {
    case pairs
    case shoppingList
    case sequence
    case change

    public var id: String { rawValue }
}

/// Difficulty of one game from 1 to 20. It follows the player: two good rounds in a row (80 % or more)
/// make it one step harder, one weak round (under 50 %) one step easier. Most rounds should succeed.
public struct SkillLevel: Codable, Hashable {
    public static let range = 1...20

    public private(set) var value: Int
    public private(set) var goodRounds: Int

    public init(value: Int = 1) {
        self.value = min(Self.range.upperBound, max(Self.range.lowerBound, value))
        goodRounds = 0
    }

    /// Records a finished round with a score from 0 to 1 and returns the change: -1, 0 or +1.
    @discardableResult
    public mutating func record(score: Double) -> Int {
        if score < 0.5 {
            goodRounds = 0
            guard value > Self.range.lowerBound else { return 0 }
            value -= 1
            return -1
        }
        guard score >= 0.8 else {
            goodRounds = 0
            return 0
        }
        goodRounds += 1
        guard goodRounds >= 2, value < Self.range.upperBound else { return 0 }
        value += 1
        goodRounds = 0
        return 1
    }

    /// A number that grows evenly from `low` at level 1 to `high` at level 20.
    public static func scaled(_ level: Int, from low: Int, to high: Int) -> Int {
        let step = Double(min(range.upperBound, max(range.lowerBound, level)) - 1) / Double(range.count - 1)
        return low + Int((Double(high - low) * step).rounded())
    }
}

/// Small random helpers on top of `SeededGenerator`, so rounds can be replayed in tests.
struct TrainingRandom {
    private var generator: SeededGenerator

    init(seed: UInt64) {
        generator = SeededGenerator(seed: seed)
    }

    mutating func int(_ upperBound: Int) -> Int {
        Int(generator.next() % UInt64(upperBound))
    }

    mutating func pick<T>(_ items: [T]) -> T {
        items[int(items.count)]
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
