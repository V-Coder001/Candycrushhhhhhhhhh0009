import Match3Core
import SpriteKit
import SwiftUI

struct GameView: View {
    let level: Level
    let onClose: () -> Void
    let onNext: (() -> Void)?

    @StateObject private var controller: GameController
    @EnvironmentObject private var progress: ProgressStore

    init(level: Level, onClose: @escaping () -> Void, onNext: (() -> Void)?) {
        self.level = level
        self.onClose = onClose
        self.onNext = onNext
        _controller = StateObject(wrappedValue: GameController(level: level))
    }

    var body: some View {
        ZStack {
            CandyBackdrop()

            VStack(spacing: 14) {
                HUDView(controller: controller)
                SpriteView(scene: controller.scene, preferredFramesPerSecond: 120, options: [.allowsTransparency])
                    .aspectRatio(CGFloat(level.columns) / CGFloat(level.rows), contentMode: .fit)
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 6)
                bottomBar
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)

            if let combo = controller.combo {
                Text(combo.word.rawValue)
                    .font(Theme.title(54, weight: .black))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(uiColor: Theme.starUI.lighter(0.3)), Theme.star,
                                                Color(uiColor: Theme.candy(.orange))],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Color(uiColor: Theme.candy(.purple)), radius: 0, x: 3, y: 3)
                    .shadow(color: Color(uiColor: Theme.candy(.purple)), radius: 0, x: -2, y: -2)
                    .shadow(color: Color(uiColor: Theme.candy(.purple)), radius: 0, x: 3, y: -2)
                    .shadow(color: Color(uiColor: Theme.candy(.purple)), radius: 0, x: -2, y: 3)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 6)
                    .rotationEffect(.degrees(-6))
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                    .id(combo.id)
                    .allowsHitTesting(false)
            }

            if controller.showResult {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
                ResultView(controller: controller,
                           onRetry: { controller.restart() },
                           onNext: onNext,
                           onClose: onClose)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            controller.onFinish = { level, stars, score in
                progress.record(level: level, stars: stars, score: score)
            }
            controller.scene.scheduleHint()
            if Demo.autoplay { controller.startAutoplay() }
        }
    }

    private var bottomBar: some View {
        HStack {
            candyButton("xmark", color: Theme.accentUI, label: "Schließen", action: onClose)
            Spacer()
            Text("Level \(level.id) · \(level.name)")
                .font(Theme.title(17))
                .candyText()
            Spacer()
            candyButton("arrow.counterclockwise", color: Theme.candy(.blue), label: "Neu starten") {
                controller.restart()
            }
        }
        .padding(.horizontal, 6)
    }

    private func candyButton(_ symbol: String, color: UIColor, label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .black))
                .candyText(Color(uiColor: color.darker(0.45)))
                .frame(width: 48, height: 48)
                .background(GlossyCircle(color: color))
        }
        .accessibilityLabel(label)
    }
}

/// Blue banner at the top: score and star meter, moves in the middle, goals on the right.
struct HUDView: View {
    @ObservedObject var controller: GameController

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Punkte")
                    .font(Theme.title(12, weight: .bold))
                    .candyText()
                Text(controller.score.formatted())
                    .font(Theme.title(20, weight: .black))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .candyText()
                StarMeter(progress: controller.progressToThreeStars,
                          marks: controller.level.starScores.map {
                              Double($0) / Double(max(1, controller.level.starScores.last ?? 1))
                          })
                    .frame(height: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Theme.bannerTop, Theme.bannerBottom],
                                         center: .top, startRadius: 4, endRadius: 50))
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: Theme.bannerEdge.opacity(0.5), radius: 3, y: 3)
                VStack(spacing: -2) {
                    Text("\(controller.movesLeft)")
                        .font(Theme.title(34, weight: .black))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(controller.movesLeft <= 3 ? Theme.star : .white)
                        .shadow(color: Theme.bannerEdge, radius: 0, x: 1.5, y: 1.5)
                    Text("Züge")
                        .font(Theme.title(11, weight: .bold))
                        .candyText()
                }
            }
            .frame(width: 84, height: 84)
            .offset(y: 10)

            HStack(spacing: 6) {
                ForEach(Array(controller.goals.enumerated()), id: \.offset) { _, goal in
                    GoalChip(progress: goal)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.25)))
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.banner)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.9), lineWidth: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                        .padding(4)
                )
                .shadow(color: Theme.bannerEdge.opacity(0.45), radius: 0, y: 4)
        )
    }
}

struct GoalChip: View {
    let progress: GoalProgress

    var body: some View {
        HStack(spacing: 4) {
            icon
                .frame(width: 26, height: 26)
            if progress.isMet {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white, Theme.greenButton)
            } else {
                Text(label)
                    .font(Theme.title(15, weight: .black))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .contentTransition(.numericText())
                    .candyText()
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
            Image(systemName: "star.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.star)
                .shadow(color: .orange, radius: 0, y: 1.5)
        case .clearJelly:
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LinearGradient(colors: [Color(uiColor: Theme.jellyUI.lighter(0.3)), Theme.jelly],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(.white, lineWidth: 1.5))
                .frame(width: 22, height: 22)
        case .collectIngredients:
            Image(uiImage: CandyArt.shared.image(for: .ingredient(.cherry), size: 26))
        case .clearChocolate:
            Image(uiImage: CandyArt.shared.image(for: .chocolate, size: 26))
        }
    }
}

struct StarMeter: View {
    let progress: Double
    let marks: [Double]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.bannerEdge.opacity(0.55))
                Capsule()
                    .fill(LinearGradient(colors: [Color(uiColor: Theme.starUI.lighter(0.3)), Theme.star],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: max(8, geo.size.width * progress))
                ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(progress >= mark ? Theme.star : Color.white.opacity(0.6))
                        .shadow(color: Theme.bannerEdge, radius: 0, y: 1)
                        .offset(x: geo.size.width * mark - 7)
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
        VStack(spacing: 18) {
            Text(won ? "Köstlich!" : "Keine Züge mehr")
                .font(Theme.title(28, weight: .black))
                .candyText(Color(uiColor: Theme.candy(.purple).darker(0.2)))
                .padding(.horizontal, 26)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [Color(uiColor: Theme.accentUI.lighter(0.2)),
                                                      Color(uiColor: Theme.candy(.purple))],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(Capsule().stroke(.white, lineWidth: 3))
                )
                .offset(y: -34)
                .padding(.bottom, -34)

            if won {
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: i == 1 ? 58 : 44, weight: .black))
                            .foregroundStyle(i < shownStars ? Theme.star : Color(uiColor: UIColor(hex: 0xD9D2E9)))
                            .shadow(color: i < shownStars ? .orange : .gray.opacity(0.4), radius: 0, y: 3)
                            .scaleEffect(i < shownStars ? 1 : 0.85)
                            .offset(y: i == 1 ? -8 : 0)
                    }
                }
            } else {
                Text("Fast geschafft. Noch ein Versuch?")
                    .font(Theme.title(16, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }

            VStack(spacing: 2) {
                Text("Punkte")
                    .font(Theme.title(13, weight: .bold))
                    .foregroundStyle(Theme.muted)
                Text(controller.score.formatted())
                    .font(Theme.title(34, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                if controller.bonus > 0 {
                    Text("inkl. Zuckerregen +\(controller.bonus.formatted())")
                        .font(Theme.title(13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }

            VStack(spacing: 10) {
                if won, let onNext {
                    candyCapsule("Weiter", color: Theme.greenButtonUI, action: onNext)
                    candyCapsule("Nochmal", color: Theme.candy(.blue), action: onRetry)
                } else {
                    candyCapsule(won ? "Nochmal" : "Nochmal versuchen", color: Theme.greenButtonUI, action: onRetry)
                }
                Button("Zur Karte", action: onClose)
                    .font(Theme.title(16, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 2)
            }
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [.white, Color(uiColor: UIColor(hex: 0xFFF0FA))],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color(uiColor: Theme.accentUI.lighter(0.4)), lineWidth: 4))
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
        )
        .padding(24)
        .task {
            guard won else { return }
            for i in 1...max(1, controller.stars) {
                try? await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { shownStars = i }
                SoundManager.shared.play(.pop, pitch: 1 + Double(i) * 0.2)
                Haptics.pop()
            }
        }
    }

    private func candyCapsule(_ title: String, color: UIColor, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.title(20, weight: .black))
                .candyText(Color(uiColor: color.darker(0.4)))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [Color(uiColor: color.lighter(0.3)), Color(uiColor: color)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(Capsule().stroke(.white, lineWidth: 3))
                        .shadow(color: Color(uiColor: color.darker(0.4)), radius: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
    }
}
