/// Reihenfolge nachtippen: fields light up one after another and are tapped back in the same order.
/// A round has three sequences of the same length.
public struct SequenceRound {
    public enum TapResult: Equatable {
        case ignored
        case correct
        /// The sequence is over, right or wrong.
        case finished(success: Bool)
    }

    public static let trialsPerRound = 3

    public let level: Int
    public let pads: Int
    public let trials: [[Int]]
    public private(set) var trialIndex = 0
    public private(set) var inputCount = 0
    public private(set) var successes = 0
    public private(set) var isWaitingForNext = false

    public static func padCount(level: Int) -> Int {
        level <= 6 ? 4 : (level <= 13 ? 6 : 9)
    }

    public static func length(level: Int) -> Int {
        SkillLevel.scaled(level, from: 3, to: 9)
    }

    public init(level: Int, seed: UInt64) {
        self.level = level
        var rng = TrainingRandom(seed: seed)
        let pads = Self.padCount(level: level)
        let length = Self.length(level: level)
        self.pads = pads
        trials = (0..<Self.trialsPerRound).map { _ in
            var sequence: [Int] = []
            while sequence.count < length {
                let pad = rng.int(pads)
                // No pad twice in a row: a repeat is hard to see when it lights up.
                if pad != sequence.last { sequence.append(pad) }
            }
            return sequence
        }
    }

    public var current: [Int] { trials[min(trialIndex, trials.count - 1)] }
    public var isComplete: Bool { trialIndex >= trials.count }
    public var score: Double { Double(successes) / Double(trials.count) }

    public mutating func tap(_ pad: Int) -> TapResult {
        guard !isComplete, !isWaitingForNext else { return .ignored }
        guard current[inputCount] == pad else {
            isWaitingForNext = true
            return .finished(success: false)
        }
        inputCount += 1
        guard inputCount == current.count else { return .correct }
        successes += 1
        isWaitingForNext = true
        return .finished(success: true)
    }

    /// Moves on to the next sequence after the player saw the result.
    public mutating func next() {
        guard isWaitingForNext else { return }
        isWaitingForNext = false
        inputCount = 0
        trialIndex += 1
    }
}
