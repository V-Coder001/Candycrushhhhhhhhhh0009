import Foundation
import Match3Core

/// Best stars and scores per level, kept in UserDefaults.
@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var stars: [Int: Int] = [:]
    @Published private(set) var bestScores: [Int: Int] = [:]

    private let defaults: UserDefaults
    private let starsKey = "progress.stars"
    private let scoresKey = "progress.scores"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        stars = Self.load(starsKey, from: defaults)
        bestScores = Self.load(scoresKey, from: defaults)
    }

    var totalStars: Int { stars.values.reduce(0, +) }

    func isUnlocked(_ level: Level) -> Bool {
        level.id == 1 || (stars[level.id - 1] ?? 0) > 0
    }

    func record(level: Level, stars newStars: Int, score: Int) {
        guard newStars > 0 else { return }
        stars[level.id] = max(stars[level.id] ?? 0, newStars)
        bestScores[level.id] = max(bestScores[level.id] ?? 0, score)
        save(stars, starsKey)
        save(bestScores, scoresKey)
    }

    func nextLevel(after level: Level) -> Level? {
        Level.campaign.first { $0.id == level.id + 1 }
    }

    private func save(_ values: [Int: Int], _ key: String) {
        defaults.set(Dictionary(uniqueKeysWithValues: values.map { (String($0.key), $0.value) }), forKey: key)
    }

    private static func load(_ key: String, from defaults: UserDefaults) -> [Int: Int] {
        guard let raw = defaults.dictionary(forKey: key) as? [String: Int] else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in Int(key).map { ($0, value) } })
    }
}
