/// The day's training: learn a shopping list, play two other games, then recall the list.
public struct DailyPlan: Equatable {
    public enum Step: Hashable {
        case learnList
        case play(BrainGame)
        case recallList
    }

    public let steps: [Step]

    /// Games that can fill the middle of a training.
    public static let middleGames: [BrainGame] = [.pairs, .sequence, .change]

    /// Picks the two games that were played longest ago. Ties go to the one that comes first on this day,
    /// so the order still rotates when nothing was played yet.
    /// - Parameters:
    ///   - lastPlayed: the day number each game was last played (days since 2001-01-01), if ever.
    ///   - day: today's day number.
    public init(lastPlayed: [BrainGame: Int], day: Int) {
        let games = Self.middleGames
        let rotation = ((day % games.count) + games.count) % games.count
        let ordered = games.indices.map { games[($0 + rotation) % games.count] }
        let chosen = ordered.enumerated()
            .sorted { a, b in
                let la = lastPlayed[a.element] ?? Int.min
                let lb = lastPlayed[b.element] ?? Int.min
                return la != lb ? la < lb : a.offset < b.offset
            }
            .prefix(2)
            .map(\.element)
        steps = [.learnList] + chosen.map { .play($0) } + [.recallList]
    }

    /// Steps the player sees as games (the list counts once).
    public var gameCount: Int { steps.count - 1 }
}
