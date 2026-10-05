/// Wechselgeld: a small purchase is paid with a note, the player picks the right change from four amounts.
public struct ChangeRound {
    public struct Task: Hashable {
        public let items: [ShoppingItem]
        /// Price per item in cents, rounded to the level's coins.
        public let prices: [Int]
        public let paid: Int
        public let options: [Int]
        /// The total is shown on easy levels; later it has to be added up.
        public let showsTotal: Bool

        public var total: Int { prices.reduce(0, +) }
        public var change: Int { paid - total }
    }

    public static let tasksPerRound = 5

    public let level: Int
    public let tasks: [Task]
    public private(set) var answers: [Int] = []

    public static func itemCount(level: Int) -> Int {
        level <= 6 ? 1 : (level <= 13 ? 2 : 3)
    }

    /// Whole euros first, then 50 and 10 cent steps, finally any cent amount.
    public static func priceStep(level: Int) -> Int {
        switch level {
        case ...5: return 100
        case ...10: return 50
        case ...15: return 10
        default: return 1
        }
    }

    public init(level: Int, seed: UInt64) {
        self.level = level
        var rng = TrainingRandom(seed: seed)
        tasks = (0..<Self.tasksPerRound).map { _ in
            Self.makeTask(level: level, rng: &rng)
        }
    }

    private static func makeTask(level: Int, rng: inout TrainingRandom) -> Task {
        let step = priceStep(level: level)
        let items = Array(rng.shuffled(ShoppingItem.catalog).prefix(itemCount(level: level)))
        let prices = items.map { item in max(step, Int((Double(item.price) / Double(step)).rounded()) * step) }
        let total = prices.reduce(0, +)
        let paid = [500, 1_000, 2_000, 5_000, 10_000].first { $0 > total } ?? 20_000
        let change = paid - total
        // Wrong answers look like typical slips: a step off, a euro off, or the euros and cents mixed up.
        var candidates = [change + step, change - step, change + 100, change - 100, change + 10, change - 10,
                          change + 50, change - 50, (change % 100) * 100 + change / 100]
        candidates = rng.shuffled(candidates.filter { $0 > 0 && $0 != change && $0 < paid })
        var options = [change]
        for candidate in candidates where options.count < 4 && !options.contains(candidate) {
            options.append(candidate)
        }
        var extra = 1
        while options.count < 4 {
            let candidate = change + extra * 200
            if !options.contains(candidate) { options.append(candidate) }
            extra += 1
        }
        return Task(items: items, prices: prices, paid: paid, options: rng.shuffled(options),
                    showsTotal: level < 8)
    }

    public var current: Task? { answers.count < tasks.count ? tasks[answers.count] : nil }
    public var isComplete: Bool { answers.count >= tasks.count }

    /// Records the answer to the current task and returns whether it was right.
    @discardableResult
    public mutating func answer(_ amount: Int) -> Bool {
        guard let task = current else { return false }
        answers.append(amount)
        return amount == task.change
    }

    public var correct: Int { zip(tasks, answers).filter { $0.0.change == $0.1 }.count }
    public var score: Double { Double(correct) / Double(tasks.count) }
}

/// Euro amounts the German way: "7,30 €".
public enum Money {
    public static func format(_ cents: Int) -> String {
        let sign = cents < 0 ? "−" : ""
        let value = abs(cents)
        let euros = value / 100
        let rest = value % 100
        let cent = rest < 10 ? "0\(rest)" : "\(rest)"
        return "\(sign)\(euros),\(cent) €"
    }
}
