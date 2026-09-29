import Match3Core
import SpriteKit
import SwiftUI

struct GameView: View {
    let level: Level
    let onClose: () -> Void
    let onNext: (() -> Void)?

    @StateObject private var controller: GameController
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.colorScheme) private var colorScheme

    init(level: Level, onClose: @escaping () -> Void, onNext: (() -> Void)?) {
        self.level = level
        self.onClose = onClose
        self.onNext = onNext
        _controller = StateObject(wrappedValue: GameController(level: level))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 18) {
                topBar
                HUDView(controller: controller)
                SpriteView(scene: controller.scene, preferredFramesPerSecond: 120, options: [.allowsTransparency])
                    .aspectRatio(CGFloat(level.columns) / CGFloat(level.rows), contentMode: .fit)
                    .frame(maxWidth: 560)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            if let combo = controller.combo {
                Text(combo.word.rawValue)
                    .font(Theme.title(46, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.accent, Theme.star], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .id(combo.id)
                    .allowsHitTesting(false)
            }

            if controller.showResult {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)
                ResultView(controller: controller,
                           onRetry: { controller.restart() },
                           onNext: onNext,
                           onClose: onClose)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            controller.scene.isDark = colorScheme == .dark
            controller.onFinish = { level, stars, score in
                progress.record(level: level, stars: stars, score: score)
            }
            controller.scene.scheduleHint()
            if Demo.autoplay { controller.startAutoplay() }
        }
        .onChange(of: colorScheme) { _, scheme in
            controller.scene.isDark = scheme == .dark
        }
    }

    private var topBar: some View {
        HStack {
            circleButton("xmark", label: "Schließen", action: onClose)
            Spacer()
            VStack(spacing: 2) {
                Text("Level \(level.id)")
                    .font(Theme.title(13, weight: .medium))
                    .foregroundStyle(Theme.muted)
                Text(level.name)
                    .font(Theme.title(18))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            circleButton("arrow.counterclockwise", label: "Neu starten") { controller.restart() }
        }
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.surface))
        }
        .accessibilityLabel(label)
    }
}

struct HUDView: View {
    @ObservedObject var controller: GameController

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 0) {
                Text("\(controller.movesLeft)")
                    .font(Theme.title(34, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(controller.movesLeft <= 3 ? Theme.accent : Theme.ink)
                Text("Züge")
                    .font(Theme.title(12, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            .frame(width: 64)

            Divider().frame(height: 44)

            HStack(spacing: 10) {
                ForEach(Array(controller.goals.enumerated()), id: \.offset) { _, goal in
                    GoalChip(progress: goal)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 6) {
                Text(controller.score.formatted())
                    .font(Theme.title(20, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.ink)
                StarMeter(progress: controller.progressToThreeStars,
                          marks: controller.level.starScores.map {
                              Double($0) / Double(max(1, controller.level.starScores.last ?? 1))
                          })
                    .frame(width: 84, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface))
    }
}

struct GoalChip: View {
    let progress: GoalProgress

    var body: some View {
        HStack(spacing: 6) {
            icon
                .frame(width: 24, height: 24)
            if progress.isMet {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(uiColor: Theme.candy(.green)))
                    .font(.system(size: 16))
            } else {
                Text(label)
                    .font(Theme.title(15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var label: String {
        switch progress.goal {
        case .score: return progress.target.formatted()
        default: return "\(progress.remaining)"
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch progress.goal {
        case .score:
            Image(systemName: "star.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.star)
        case .clearJelly:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.jelly.opacity(0.7))
                .frame(width: 20, height: 20)
        case .collectIngredients:
            Image(uiImage: CandyArt.shared.image(for: .ingredient(.cherry), size: 24))
        case .clearChocolate:
            Image(uiImage: CandyArt.shared.image(for: .chocolate, size: 24))
        }
    }
}

struct StarMeter: View {
    let progress: Double
    let marks: [Double]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.muted.opacity(0.18))
                Capsule()
                    .fill(Theme.star)
                    .frame(width: geo.size.width * progress)
                ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                    Circle()
                        .fill(progress >= mark ? Theme.star : Theme.surface)
                        .overlay(Circle().stroke(Theme.star, lineWidth: 1.5))
                        .frame(width: 8, height: 8)
                        .offset(x: geo.size.width * mark - 4)
                }
            }
        }
        .animation(.snappy, value: progress)
    }
}

struct ResultView: View {
    @ObservedObject var controller: GameController
    let onRetry: () -> Void
    let onNext: (() -> Void)?
    let onClose: () -> Void

    @State private var shownStars = 0

    private var won: Bool { controller.status == .won }

    var body: some View {
        VStack(spacing: 20) {
            Text(won ? "Geschafft" : "Fast")
                .font(Theme.title(32, weight: .bold))
                .foregroundStyle(Theme.ink)

            if won {
                HStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < shownStars ? "star.fill" : "star")
                            .font(.system(size: i == 1 ? 44 : 34, weight: .semibold))
                            .foregroundStyle(i < shownStars ? Theme.star : Theme.muted.opacity(0.35))
                            .scaleEffect(i < shownStars ? 1 : 0.85)
                            .offset(y: i == 1 ? -6 : 0)
                    }
                }
            } else {
                Text("Keine Züge mehr. Noch ein Versuch?")
                    .font(Theme.title(16, weight: .regular))
                    .foregroundStyle(Theme.muted)
            }

            VStack(spacing: 4) {
                Text(controller.score.formatted())
                    .font(Theme.title(28, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                if controller.bonus > 0 {
                    Text("inkl. Zuckerregen +\(controller.bonus.formatted())")
                        .font(Theme.title(13, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
            }

            VStack(spacing: 10) {
                if won, let onNext {
                    primaryButton("Nächstes Level", action: onNext)
                    secondaryButton("Nochmal", action: onRetry)
                } else {
                    primaryButton(won ? "Nochmal" : "Nochmal versuchen", action: onRetry)
                }
                secondaryButton("Zur Übersicht", action: onClose)
            }
        }
        .padding(28)
        .frame(maxWidth: 360)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Theme.surface))
        .padding(24)
        .task {
            guard won else { return }
            for i in 1...max(1, controller.stars) {
                try? await Task.sleep(nanoseconds: 280_000_000)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { shownStars = i }
                SoundManager.shared.play(.pop, pitch: 1 + Double(i) * 0.2)
                Haptics.pop()
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.title(17))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Theme.accent))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.title(16, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(Theme.ink)
        }
        .buttonStyle(.plain)
    }
}
