import Match3Core
import SwiftUI

/// Connects the game model, the SpriteKit scene and the SwiftUI HUD.
@MainActor
final class GameController: ObservableObject, GameSceneDelegate {
    struct ComboBanner: Identifiable, Equatable {
        let id = UUID()
        let word: ComboWord
    }

    let level: Level
    let scene: GameScene
    private(set) var game: Game

    /// Score and goals follow the animation step by step rather than jumping ahead.
    @Published private(set) var score = 0
    @Published private(set) var movesLeft: Int
    @Published private(set) var goals: [GoalProgress]
    @Published private(set) var status: GameStatus = .playing
    @Published private(set) var stars = 0
    @Published private(set) var bonus = 0
    @Published private(set) var showResult = false
    @Published var combo: ComboBanner?
    /// Stars the running score has already passed (drives the HUD meter and its little fanfare).
    @Published private(set) var starsReached = 0
    @Published private(set) var showSugarRush = false

    var onFinish: ((Level, _ stars: Int, _ score: Int) -> Void)?

    private var collectedShown = 0
    private var servedShown = 0

    init(level: Level) {
        self.level = level
        let game = Demo.seed.map { Game(level: level, seed: $0) } ?? Game(level: level)
        self.game = game
        movesLeft = game.movesLeft
        goals = game.goalProgress
        scene = GameScene(board: game.board)
        scene.gameDelegate = self
    }

    var progressToThreeStars: Double {
        guard let top = level.starScores.last, top > 0 else { return 0 }
        return min(1, Double(score) / Double(top))
    }

    func restart() {
        game = Game(level: level)
        score = 0
        collectedShown = 0
        servedShown = 0
        movesLeft = game.movesLeft
        goals = game.goalProgress
        status = .playing
        stars = 0
        bonus = 0
        starsReached = 0
        showSugarRush = false
        showResult = false
        SoundManager.shared.duckMusic(false)
        combo = nil
        scene.reset(board: game.board)
        scene.scheduleHint()
    }

    /// Plays suggested moves by itself (demo videos and screenshots).
    func startAutoplay() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            while let self, self.status == .playing {
                if !self.scene.isBusy, let (a, b) = self.game.mixHint() ?? self.game.hint() {
                    self.scene.performSwap(a, b)
                }
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }
    }

    // MARK: GameSceneDelegate

    func scene(_ scene: GameScene, requestSwap from: Position, to: Position) -> MoveResult? {
        guard status == .playing else { return nil }
        let result = game.swap(from, to)
        if result.isValid {
            // Moves spent by the sugar rush count down while it plays.
            let rushMoves = result.sugarRush.reduce(0) { $0 + $1.movesSpent }
            withAnimation(.snappy) { movesLeft = game.movesLeft + rushMoves }
        }
        return result
    }

    func sceneDidApply(_ step: CascadeStep) {
        collectedShown += step.collected.count
        servedShown += step.served.count
        withAnimation(.snappy) {
            if step.movesSpent > 0 { movesLeft = max(0, movesLeft - step.movesSpent) }
            score += step.scoreGained
            goals = GoalProgress.evaluate(goals: level.goals, score: score, board: step.board,
                                          collected: collectedShown, served: servedShown,
                                          initialJelly: game.initialJelly,
                                          initialChocolate: game.initialChocolate)
        }
        updateStarsReached()
    }

    func sceneDidStartSugarRush() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { showSugarRush = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeOut(duration: 0.3)) { showSugarRush = false }
        }
    }

    private func updateStarsReached() {
        let reached = level.starScores.filter { score >= $0 }.count
        guard reached > starsReached else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { starsReached = reached }
        SoundManager.shared.play(.star, pitch: 1 + Double(reached - 1) * 0.12, volume: 0.8)
        Haptics.special()
    }

    func sceneDidShow(_ word: ComboWord) {
        let banner = ComboBanner(word: word)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { combo = banner }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            if combo == banner {
                withAnimation(.easeOut(duration: 0.3)) { combo = nil }
            }
        }
    }

    func sceneDidFinish(_ move: MoveResult) {
        withAnimation(.snappy) {
            score = game.score
            goals = game.goalProgress
            movesLeft = game.movesLeft
        }
        updateStarsReached()
        guard game.status != .playing, status == .playing else { return }
        status = game.status
        stars = game.stars
        bonus = move.bonusScore
        SoundManager.shared.duckMusic(true)
        if status == .won {
            SoundManager.shared.play(.win)
            Haptics.success()
        } else {
            SoundManager.shared.play(.lose)
        }
        onFinish?(level, stars, game.score)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showResult = true }
        }
    }

    func sceneHint() -> (Position, Position)? {
        status == .playing ? game.mixHint() ?? game.hint() : nil
    }
}
