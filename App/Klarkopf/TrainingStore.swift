import Foundation
import Match3Core

/// Levels, last played days and training days, kept on the device in UserDefaults.
@MainActor
final class TrainingStore: ObservableObject {
    @Published private(set) var levels: [BrainGame: SkillLevel] = [:]
    @Published private(set) var lastPlayed: [BrainGame: Int] = [:]
    @Published private(set) var trainingDays: Set<Int> = []

    private let defaults: UserDefaults
    private let key = "training.state"

    private struct Saved: Codable {
        var levels: [String: SkillLevel]
        var lastPlayed: [String: Int]
        var days: [Int]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        levels = Dictionary(uniqueKeysWithValues: saved.levels.compactMap { key, value in
            BrainGame(rawValue: key).map { ($0, value) }
        })
        lastPlayed = Dictionary(uniqueKeysWithValues: saved.lastPlayed.compactMap { key, value in
            BrainGame(rawValue: key).map { ($0, value) }
        })
        trainingDays = Set(saved.days)
    }

    func level(_ game: BrainGame) -> Int {
        levels[game]?.value ?? 1
    }

    /// Stores a finished round and returns the level change (-1, 0 or +1).
    @discardableResult
    func record(_ game: BrainGame, score: Double) -> Int {
        var level = levels[game] ?? SkillLevel()
        let change = level.record(score: score)
        levels[game] = level
        lastPlayed[game] = Self.today
        save()
        return change
    }

    func finishTraining() {
        trainingDays.insert(Self.today)
        save()
    }

    var trainedToday: Bool { trainingDays.contains(Self.today) }

    var daysThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        return trainingDays.filter { day in
            calendar.isDate(Self.date(of: day), equalTo: now, toGranularity: .month)
        }.count
    }

    func plan() -> DailyPlan {
        DailyPlan(lastPlayed: lastPlayed, day: Self.today)
    }

    /// Random rounds, or fixed ones for screenshots (`-demoSeed`).
    func seed() -> UInt64 {
        Demo.seed ?? UInt64.random(in: 1...UInt64.max)
    }

    // MARK: Days

    private static let reference = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))

    /// Days since 1 January 2001 in the user's calendar.
    static var today: Int {
        Calendar.current.dateComponents([.day], from: reference, to: Calendar.current.startOfDay(for: Date())).day ?? 0
    }

    static func date(of day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day, to: reference) ?? Date()
    }

    private func save() {
        let saved = Saved(levels: Dictionary(uniqueKeysWithValues: levels.map { ($0.key.rawValue, $0.value) }),
                          lastPlayed: Dictionary(uniqueKeysWithValues: lastPlayed.map { ($0.key.rawValue, $0.value) }),
                          days: trainingDays.sorted())
        if let data = try? JSONEncoder().encode(saved) {
            defaults.set(data, forKey: key)
        }
    }
}
