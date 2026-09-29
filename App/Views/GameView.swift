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
                    .background(
                        // Soft light behind the board so it floats over the sky.
                        RadialGradient(colors: [.white.opacity(0.55), .white.opacity(0)], center: .center,
                                       startRadius: 60, endRadius: 260)
                            .scaleEffect(1.3)
                    )
                    .padding(.horizontal, 4)
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

            if controller.showSugarRush {
                SugarRushBanner()
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            if controller.showResult {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
                if controller.status == .won {
                    ConfettiView()
                }
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
            CandyIconButton(symbol: "xmark", color: Theme.accentUI, label: "Schließen", action: onClose)
            Spacer()
            VStack(spacing: 0) {
                Text("Level \(level.id)")
                    .font(Theme.title(13, weight: .heavy))
                    .candyText()
                Text(level.name)
                    .font(Theme.title(19, weight: .black))
                    .candyText()
            }
            Spacer()
            CandyIconButton(symbol: "arrow.counterclockwise", color: Theme.candy(.blue), label: "Neu starten") {
                controller.restart()
            }
        }
        .padding(.horizontal, 6)
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
                          },
                          reached: controller.starsReached)
                    .frame(height: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                let low = controller.movesLeft <= 5 && controller.status == .playing
                Circle()
                    .fill(RadialGradient(colors: low ? [Color(uiColor: Theme.accentUI.lighter(0.2)), Theme.accent]
                                                     : [Theme.bannerTop, Theme.bannerBottom],
                                         center: .top, startRadius: 4, endRadius: 50))
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .overlay(
                        Ellipse()
                            .fill(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom))
                            .frame(width: 52, height: 26)
                            .offset(y: -22)
                    )
                    .shadow(color: Theme.bannerEdge.opacity(0.5), radius: 0, y: 4)
                    .animation(.easeInOut(duration: 0.3), value: low)
                VStack(spacing: -2) {
                    Text("\(controller.movesLeft)")
                        .font(Theme.title(34, weight: .black))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(.white)
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

    private var icon: some View {
        GoalIcon(goal: progress.goal)
    }
}

struct StarMeter: View {
    let progress: Double
    let marks: [Double]
    var reached = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.bannerEdge.opacity(0.55))
                Capsule()
                    .fill(LinearGradient(colors: [Color(uiColor: Theme.starUI.lighter(0.3)), Theme.star],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().fill(.white.opacity(0.35)).frame(height: 3).padding(.horizontal, 4)
                        .offset(y: -2))
                    .frame(width: max(8, geo.size.width * progress))
                ForEach(Array(marks.enumerated()), id: \.offset) { index, mark in
                    let lit = index < reached
                    Image(systemName: "star.fill")
                        .font(.system(size: lit ? 17 : 13, weight: .black))
                        .foregroundStyle(lit ? Theme.star : Color.white.opacity(0.6))
                        .shadow(color: lit ? .orange : Theme.bannerEdge, radius: 0, y: 1.5)
                        .scaleEffect(lit ? 1.15 : 1)
                        .offset(x: geo.size.width * mark - (lit ? 9 : 7))
                }
            }
        }
        .animation(.snappy, value: progress)
        .animation(.spring(response: 0.3, dampingFraction: 0.4), value: reached)
    }
}

/// "Zuckerrausch!" banner when the level is won and the leftover moves turn into candy.
struct SugarRushBanner: View {
    @State private var spin = false

    var body: some View {
        ZStack {
            Image(systemName: "sparkles")
                .font(.system(size: 160, weight: .bold))
                .foregroundStyle(Theme.star.opacity(0.9))
                .rotationEffect(.degrees(spin ? 20 : -20))
            Text("Zuckerrausch!")
                .font(Theme.title(50, weight: .black))
                .foregroundStyle(LinearGradient(colors: [Color(uiColor: Theme.accentUI.lighter(0.45)), Theme.accent],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: .white, radius: 0, x: 3, y: 3)
                .shadow(color: .white, radius: 0, x: -3, y: -3)
                .shadow(color: .white, radius: 0, x: 3, y: -3)
                .shadow(color: .white, radius: 0, x: -3, y: 3)
                .shadow(color: Color(uiColor: Theme.candy(.purple)), radius: 0, y: 6)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 8)
                .rotationEffect(.degrees(-5))
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { spin = true }
        }
    }
}

struct ResultView: View {
    @ObservedObject var controller: GameController
    let onRetry: () -> Void
    let onNext: (() -> Void)?
    let onClose: () -> Void

    @State private var shownStars = 0
    @State private var shownScore = 0

    private var won: Bool { controller.status == .won }

    private var title: String {
        guard won else { return "Keine Züge mehr" }
        switch controller.stars {
        case 3: return "Göttlich!"
        case 2: return "Köstlich!"
        default: return "Geschafft!"
        }
    }

    var body: some View {
        CandyPanel(title: title, ribbon: won ? Theme.accentUI : Theme.candy(.blue)) {
            VStack(spacing: 16) {
                if won {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            let lit = i < shownStars
                            Image(systemName: "star.fill")
                                .font(.system(size: i == 1 ? 64 : 48, weight: .black))
                                .foregroundStyle(lit
                                    ? LinearGradient(colors: [Color(uiColor: Theme.starUI.lighter(0.4)), Theme.star],
                                                     startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [Color(uiColor: UIColor(hex: 0xE6E0F0))],
                                                     startPoint: .top, endPoint: .bottom))
                                .shadow(color: lit ? .orange : .gray.opacity(0.35), radius: 0, y: 4)
                                .scaleEffect(lit ? 1 : 0.8)
                                .rotationEffect(.degrees(lit ? Double(i - 1) * 12 : 0))
                                .offset(y: i == 1 ? -10 : 0)
                        }
                    }
                    .padding(.top, 4)
                } else {
                    Image(systemName: "heart.slash.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    Text("Fast geschafft. Noch ein Versuch?")
                        .font(Theme.title(16, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }

                VStack(spacing: 2) {
                    Text("Punkte")
                        .font(Theme.title(13, weight: .bold))
                        .foregroundStyle(Theme.muted)
                    Text(shownScore.formatted())
                        .font(Theme.title(38, weight: .black))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(shownScore)))
                        .foregroundStyle(Theme.ink)
                    if controller.bonus > 0 {
                        Label("Zuckerrausch +\(controller.bonus.formatted())", systemImage: "sparkles")
                            .font(Theme.title(14, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                }

                VStack(spacing: 12) {
                    if won, let onNext {
                        CandyCapsuleButton(title: "Weiter", color: Theme.greenButtonUI, icon: "play.fill", action: onNext)
                        CandyCapsuleButton(title: "Nochmal", color: Theme.candy(.blue), icon: "arrow.counterclockwise",
                                           action: onRetry)
                    } else {
                        CandyCapsuleButton(title: won ? "Nochmal" : "Nochmal versuchen", color: Theme.greenButtonUI,
                                           icon: "arrow.counterclockwise", action: onRetry)
                    }
                    Button("Zur Karte", action: onClose)
                        .font(Theme.title(16, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .buttonStyle(CandyPressStyle())
                        .padding(.top, 2)
                }
            }
        }
        .padding(24)
        .task {
            // Count the score up, then drop the stars in one by one.
            let target = controller.score
            let steps = 24
            for i in 1...steps {
                withAnimation(.linear(duration: 0.03)) { shownScore = target * i / steps }
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
            guard won else { return }
            for i in 1...max(1, controller.stars) {
                try? await Task.sleep(nanoseconds: 280_000_000)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { shownStars = i }
                SoundManager.shared.play(.star, pitch: 1 + Double(i - 1) * 0.15)
                Haptics.pop()
            }
        }
    }
}
