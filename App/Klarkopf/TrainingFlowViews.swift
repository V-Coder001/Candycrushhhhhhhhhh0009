import Match3Core
import SwiftUI

/// One round of any game. Shopping list played on its own goes straight from learning to recalling.
struct GameHost: View {
    let game: BrainGame
    let level: Int
    let seed: UInt64
    let onFinish: (Double) -> Void

    var body: some View {
        switch game {
        case .pairs: PairsGameView(level: level, seed: seed, onFinish: onFinish)
        case .sequence: SequenceGameView(level: level, seed: seed, onFinish: onFinish)
        case .change: ChangeGameView(level: level, seed: seed, onFinish: onFinish)
        case .shoppingList: ShoppingSoloView(level: level, seed: seed, onFinish: onFinish)
        }
    }
}

struct ShoppingSoloView: View {
    let onFinish: (Double) -> Void
    @State private var round: ShoppingListRound
    @State private var learned = false

    init(level: Int, seed: UInt64, onFinish: @escaping (Double) -> Void) {
        self.onFinish = onFinish
        _round = State(initialValue: ShoppingListRound(level: level, seed: seed))
    }

    var body: some View {
        if learned {
            ShoppingRecallView(round: $round, onFinish: onFinish)
        } else {
            ShoppingLearnView(round: round, laterNote: "Gleich werden Sie danach gefragt.") { learned = true }
        }
    }
}

struct RoundResult: Equatable {
    let game: BrainGame
    let score: Double
    let change: Int
}

/// Calm feedback after a round: praise first, then what happens to the difficulty.
struct RoundResultView: View {
    let result: RoundResult
    var primaryTitle = "Weiter"
    var secondaryTitle: String?
    let onPrimary: () -> Void
    var onSecondary: (() -> Void)?

    private var headline: String {
        switch result.score {
        case 0.8...: return "Sehr gut gemacht!"
        case 0.5...: return "Gut gemacht!"
        default: return "Schön, dass Sie es versucht haben."
        }
    }

    private var levelNote: String {
        switch result.change {
        case 1...: return "Beim nächsten Mal wird es etwas anspruchsvoller."
        case ..<0: return "Beim nächsten Mal wird es etwas leichter."
        default: return "Die Schwierigkeit bleibt gleich."
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: result.score >= 0.5 ? "checkmark.seal.fill" : "heart.fill")
                .font(.system(size: 76))
                .foregroundStyle(result.score >= 0.5 ? KTheme.good : KTheme.accent)
                .accessibilityHidden(true)
            Text(headline)
                .font(KTheme.title)
                .foregroundStyle(KTheme.ink)
                .multilineTextAlignment(.center)
            Text("\(result.game.title) · \(levelNote)")
                .font(KTheme.body)
                .foregroundStyle(KTheme.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            KButton(title: primaryTitle, systemImage: "arrow.right", action: onPrimary)
            if let secondaryTitle, let onSecondary {
                KButton(title: secondaryTitle, kind: .secondary, action: onSecondary)
            }
        }
        .padding(24)
    }
}

/// "Teil 2 von 4" with dots, and a way out at any time.
struct TrainingHeader: View {
    let title: String
    let step: Int?
    let total: Int?
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(KTheme.bodyBold)
                    .foregroundStyle(KTheme.ink)
                if let step, let total {
                    Text("Teil \(step + 1) von \(total)")
                        .font(KTheme.small)
                        .foregroundStyle(KTheme.secondary)
                    HStack(spacing: 8) {
                        ForEach(0..<total, id: \.self) { i in
                            Capsule()
                                .fill(i <= step ? KTheme.accent : KTheme.line)
                                .frame(width: 28, height: 8)
                        }
                    }
                    .accessibilityHidden(true)
                }
            }
            Spacer()
            Button(action: onClose) {
                Text("Beenden")
                    .font(KTheme.bodyBold)
                    .foregroundStyle(KTheme.accent)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
                    .background(Capsule().stroke(KTheme.accent, lineWidth: 2))
            }
            .buttonStyle(KPressStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(KTheme.background)
    }
}

/// The daily training: list, two games, list again, then a short review.
struct DailyTrainingView: View {
    let plan: DailyPlan
    let onClose: () -> Void

    @EnvironmentObject private var training: TrainingStore
    @State private var stepIndex = 0
    @State private var shopping: ShoppingListRound
    @State private var result: RoundResult?
    @State private var finished = false
    private let seed: UInt64

    init(plan: DailyPlan, listLevel: Int, seed: UInt64, onClose: @escaping () -> Void) {
        self.plan = plan
        self.onClose = onClose
        self.seed = seed
        _shopping = State(initialValue: ShoppingListRound(level: listLevel, seed: seed))
    }

    var body: some View {
        VStack(spacing: 0) {
            TrainingHeader(title: "Tagestraining", step: finished ? nil : stepIndex,
                           total: finished ? nil : plan.steps.count, onClose: onClose)
            Group {
                if finished {
                    DayReviewView(days: training.daysThisMonth, onClose: onClose)
                } else if let result {
                    RoundResultView(result: result,
                                    primaryTitle: stepIndex + 1 < plan.steps.count ? "Weiter" : "Training abschließen",
                                    onPrimary: advance)
                } else {
                    step
                        .id(stepIndex)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(KTheme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var step: some View {
        switch plan.steps[stepIndex] {
        case .learnList:
            ShoppingLearnView(round: shopping) { stepIndex += 1 }
        case let .play(game):
            GameHost(game: game, level: training.level(game), seed: seed &+ UInt64(stepIndex)) { score in
                result = RoundResult(game: game, score: score, change: training.record(game, score: score))
            }
        case .recallList:
            ShoppingRecallView(round: $shopping) { score in
                result = RoundResult(game: .shoppingList, score: score,
                                     change: training.record(.shoppingList, score: score))
            }
        }
    }

    private func advance() {
        result = nil
        if stepIndex + 1 < plan.steps.count {
            stepIndex += 1
        } else {
            training.finishTraining()
            finished = true
            Haptics.success()
        }
    }
}

struct DayReviewView: View {
    let days: Int
    let onClose: () -> Void

    private var daysText: String {
        days == 1 ? "Das war Ihr erster Trainingstag in diesem Monat."
            : "Das war Ihr \(days). Trainingstag in diesem Monat."
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sun.max.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color(uiColor: UIColor(hex: 0xE0A21B)))
                .accessibilityHidden(true)
            Text("Training geschafft!")
                .font(KTheme.title)
                .foregroundStyle(KTheme.ink)
            Text(daysText)
                .font(KTheme.body)
                .foregroundStyle(KTheme.secondary)
                .multilineTextAlignment(.center)
            Text("Morgen wartet ein neues Training auf Sie.")
                .font(KTheme.body)
                .foregroundStyle(KTheme.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            KButton(title: "Zur Startseite", systemImage: "house.fill", action: onClose)
        }
        .padding(24)
    }
}

/// A single game picked from the list, as often as the player likes.
struct SingleGameView: View {
    let game: BrainGame
    let onClose: () -> Void

    @EnvironmentObject private var training: TrainingStore
    @State private var roundNumber = 0
    @State private var result: RoundResult?
    @State private var seed = UInt64.random(in: 1...UInt64.max)

    init(game: BrainGame, onClose: @escaping () -> Void) {
        self.game = game
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            TrainingHeader(title: game.title, step: nil, total: nil, onClose: onClose)
            Group {
                if let result {
                    RoundResultView(result: result, primaryTitle: "Noch eine Runde", secondaryTitle: "Fertig",
                                    onPrimary: {
                                        self.result = nil
                                        roundNumber += 1
                                    },
                                    onSecondary: onClose)
                } else {
                    GameHost(game: game, level: training.level(game),
                             seed: (Demo.seed ?? seed) &+ UInt64(roundNumber)) { score in
                        result = RoundResult(game: game, score: score, change: training.record(game, score: score))
                    }
                    .id(roundNumber)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(KTheme.background.ignoresSafeArea())
    }
}
