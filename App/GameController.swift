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
    /// The hammer is picked up: the next tap on the board smashes that cell.
    @Published var hammerArmed = false {
        didSet { scene.hammerArmed = hammerArmed }
    }
    /// Boosters spent in this attempt (including extra moves taken at the start).
    @Published private(set) var boostersUsed = 0
    /// Booster earned by winning this level for the first time.
    @Published private(set) var reward: Booster?
    /// Short text over the HUD, e.g. "+5 Züge".
    @Published private(set) var toast: String?

    /// Saves the result and returns the booster earned for a first win.
    var onFinish: ((Level, _ stars: Int, _ score: Int) -> Booster?)?
    /// The player's booster stock.
    weak var inventory: ProgressStore?

    private var collectedShown = 0
    private var servedShown = 0

    init(level: Level, bonusMoves: Int = 0) {
        self.level = level
        let game = Demo.seed.map { Game(level: level, seed: $0) } ?? Game(level: level)
        if bonusMoves > 0 { game.addMoves(bonusMoves) }
        self.game = game
        movesLeft = game.movesLeft
        goals = game.goalProgress
        scene = GameScene(board: game.board)
        scene.gameDelegate = self
        if bonusMoves > 0 { boostersUsed = 1 }
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
        hammerArmed = false
        boostersUsed = 0
        reward = nil
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

    // MARK: Boosters

    func tapBooster(_ booster: Booster) {
        guard status == .playing, let inventory, inventory.count(of: booster) > 0 else {
            Haptics.invalid()
            return
        }
        switch booster {
        case .hammer:
            withAnimation(.snappy) { hammerArmed.toggle() }
            Haptics.tap()
        case .extraMoves:
            // The last move may already have won the level while it is still animating.
            guard game.status != .won, inventory.use(.extraMoves) else { return }
            game.addMoves(Booster.extraMovesAmount)
            boostersUsed += 1
            withAnimation(.snappy) { movesLeft = game.movesLeft }
            showToast("+\(Booster.extraMovesAmount) Züge")
            SoundManager.shared.play(.special)
            Haptics.special()
        case .colorMixer:
            guard !scene.isBusy, let mixed = game.useColorMixer() else { return }
            inventory.use(.colorMixer)
            boostersUsed += 1
            withAnimation(.snappy) { hammerArmed = false }
            scene.playColorMixer(to: mixed)
        }
    }

    /// "Keine Züge mehr": spend extra moves and play on.
    func continueWithExtraMoves() {
        guard status == .lost, let inventory, inventory.use(.extraMoves) else { return }
        game.addMoves(Booster.extraMovesAmount)
        boostersUsed += 1
        if game.board != scene.board {
            // Reviving can shuffle a board without moves.
            scene.reset(board: game.board)
        }
        status = .playing
        stars = 0
        bonus = 0
        SoundManager.shared.duckMusic(false)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showResult = false
            movesLeft = game.movesLeft
        }
        showToast("+\(Booster.extraMovesAmount) Züge")
        scene.scheduleHint()
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { toast = text }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if toast == text {
                withAnimation(.easeOut(duration: 0.3)) { toast = nil }
            }
        }
    }

    // MARK: GameSceneDelegate

    func scene(_ scene: GameScene, requestHammerAt p: Position) -> MoveResult? {
        guard status == .playing, hammerArmed, let inventory else { return nil }
        // Not a target (an ingredient, say): the scene wiggles, the hammer stays in hand.
        guard game.canHammer(p) else { return game.useHammer(at: p) }
        guard inventory.use(.hammer) else {
            hammerArmed = false
            return nil
        }
        let result = game.useHammer(at: p)
        boostersUsed += 1
        let rushMoves = result.sugarRush.reduce(0) { $0 + $1.movesSpent }
        withAnimation(.snappy) {
            hammerArmed = false
            movesLeft = game.movesLeft + rushMoves
        }
        return result
    }

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
        hammerArmed = false
        stars = game.stars
        bonus = move.bonusScore
        SoundManager.shared.duckMusic(true)
        if status == .won {
            SoundManager.shared.play(.win)
            Haptics.success()
        } else {
            SoundManager.shared.play(.lose)
        }
        reward = onFinish?(level, stars, game.score)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showResult = true }
        }
    }

    func sceneHint() -> (Position, Position)? {
        status == .playing ? game.mixHint() ?? game.hint() : nil
    }
}
