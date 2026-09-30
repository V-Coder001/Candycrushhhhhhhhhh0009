import Foundation
import Match3Core

/// Best stars and scores per level and the booster stock, kept in UserDefaults.
@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var stars: [Int: Int] = [:]
    @Published private(set) var bestScores: [Int: Int] = [:]
    @Published private(set) var boosters: [Booster: Int] = [:]

    private let defaults: UserDefaults
    private let starsKey = "progress.stars"
    private let scoresKey = "progress.scores"
    private let boostersKey = "progress.boosters"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        stars = Self.load(starsKey, from: defaults)
        bestScores = Self.load(scoresKey, from: defaults)
        if let raw = defaults.dictionary(forKey: boostersKey) as? [String: Int] {
            boosters = Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
                Booster(rawValue: key).map { ($0, value) }
            })
        } else {
            boosters = Dictionary(uniqueKeysWithValues: Booster.allCases.map { ($0, Booster.starterCount) })
            saveBoosters()
        }
    }

    var totalStars: Int { stars.values.reduce(0, +) }

    func isUnlocked(_ level: Level) -> Bool {
        level.id == 1 || (stars[level.id - 1] ?? 0) > 0
    }

    /// Saves a finished level. Returns the booster earned for beating it the first time.
    @discardableResult
    func record(level: Level, stars newStars: Int, score: Int) -> Booster? {
        guard newStars > 0 else { return nil }
        let firstWin = (stars[level.id] ?? 0) == 0
        stars[level.id] = max(stars[level.id] ?? 0, newStars)
        bestScores[level.id] = max(bestScores[level.id] ?? 0, score)
        save(stars, starsKey)
        save(bestScores, scoresKey)
        guard firstWin else { return nil }
        let reward = Booster.reward(forLevel: level.id)
        grant(reward)
        return reward
    }

    func nextLevel(after level: Level) -> Level? {
        let levels = level.id >= Level.mixLabFirstID ? Level.mixLab : Level.campaign
        return levels.first { $0.id == level.id + 1 }
    }

    // MARK: Boosters

    func count(of booster: Booster) -> Int { boosters[booster] ?? 0 }

    /// Takes one booster from the stock. False if none is left.
    @discardableResult
    func use(_ booster: Booster) -> Bool {
        guard count(of: booster) > 0 else { return false }
        boosters[booster] = count(of: booster) - 1
        saveBoosters()
        return true
    }

    func grant(_ booster: Booster, _ amount: Int = 1) {
        boosters[booster] = count(of: booster) + amount
        saveBoosters()
    }

    // MARK: Storage

    private func saveBoosters() {
        defaults.set(Dictionary(uniqueKeysWithValues: boosters.map { ($0.key.rawValue, $0.value) }), forKey: boostersKey)
    }

    private func save(_ values: [Int: Int], _ key: String) {
        defaults.set(Dictionary(uniqueKeysWithValues: values.map { (String($0.key), $0.value) }), forKey: key)
    }

    private static func load(_ key: String, from defaults: UserDefaults) -> [Int: Int] {
        guard let raw = defaults.dictionary(forKey: key) as? [String: Int] else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in Int(key).map { ($0, value) } })
    }
}
