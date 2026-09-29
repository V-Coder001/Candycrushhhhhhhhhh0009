import Match3Core
import SwiftUI

/// Level map: a candy road winding down through the sky, one glossy disc per level.
struct RootView: View {
    @EnvironmentObject private var progress: ProgressStore
    @State private var playing: Level?
    @State private var intro: Level?
    @State private var showSettings = false

    private static let spacing: CGFloat = 118

    var body: some View {
        ZStack {
            CandyBackdrop()
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        header
                        map
                            .padding(.bottom, 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .onAppear {
                    if let current = currentLevel { proxy.scrollTo(current.id, anchor: .center) }
                }
            }

            if let level = intro {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { closeIntro() }
                    .transition(.opacity)
                LevelIntroView(level: level, stars: progress.stars[level.id] ?? 0,
                               onPlay: {
                                   closeIntro()
                                   playing = level
                               },
                               onClose: closeIntro)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            SoundManager.shared.updateMusic()
            if playing == nil, let level = Demo.level { playing = level }
            if intro == nil, let level = Demo.intro { intro = level }
        }
        .fullScreenCover(item: $playing) { level in
            GameView(level: level,
                     onClose: { playing = nil },
                     onNext: nextAction(after: level))
                .id(level.id)
                .environmentObject(progress)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium])
        }
    }

    private var currentLevel: Level? {
        Level.campaign.last { progress.isUnlocked($0) }
    }

    private func open(_ level: Level) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { intro = level }
    }

    private func closeIntro() {
        withAnimation(.easeOut(duration: 0.2)) { intro = nil }
    }

    private func nextAction(after level: Level) -> (() -> Void)? {
        guard let next = progress.nextLevel(after: level) else { return nil }
        return { playing = next }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Theme.star)
                    .shadow(color: .orange.opacity(0.7), radius: 0, y: 1.5)
                Text("\(progress.totalStars)")
                    .monospacedDigit()
                    .candyText()
            }
            .font(Theme.title(19))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(Theme.banner)
                    .overlay(Capsule().fill(LinearGradient(colors: [.white.opacity(0.4), .clear],
                                                           startPoint: .top, endPoint: .center)).padding(2))
                    .overlay(Capsule().stroke(.white, lineWidth: 2.5))
                    .shadow(color: Theme.bannerEdge.opacity(0.5), radius: 0, y: 3)
            )

            Spacer()
            Logo()
            Spacer()

            CandyIconButton(symbol: "gearshape.fill", color: Theme.accentUI, label: "Einstellungen", size: 46) {
                showSettings = true
            }
        }
    }

    // MARK: Map

    private var map: some View {
        let count = Level.campaign.count
        let height = CGFloat(count) * Self.spacing + 40
        return ZStack(alignment: .top) {
            // Candy road: a wide sugar-white band with pink stripes painted on.
            MapPath(count: count, spacing: Self.spacing)
                .stroke(Color(uiColor: UIColor(hex: 0x1A4D8F, alpha: 0.18)),
                        style: StrokeStyle(lineWidth: 34, lineCap: .round, lineJoin: .round))
                .offset(y: 5)
            MapPath(count: count, spacing: Self.spacing)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round))
            MapPath(count: count, spacing: Self.spacing)
                .stroke(Color(uiColor: Theme.accentUI.lighter(0.25)),
                        style: StrokeStyle(lineWidth: 12, lineCap: .butt, lineJoin: .round, dash: [12, 14]))

            ForEach(Level.campaign) { level in
                let index = level.id - 1
                LevelNode(level: level,
                          stars: progress.stars[level.id] ?? 0,
                          unlocked: progress.isUnlocked(level),
                          isCurrent: level.id == currentLevel?.id) {
                    open(level)
                }
                .id(level.id)
                .offset(x: MapPath.offset(for: index), y: MapPath.y(for: index, spacing: Self.spacing) - 50)
            }

            ForEach(0..<(count + 5) / 6, id: \.self) { episode in
                EpisodeSign(number: episode + 1)
                    .offset(y: MapPath.y(for: episode * 6, spacing: Self.spacing) - 108)
            }
        }
        .frame(height: height + 40, alignment: .top)
        .padding(.top, 70)
    }
}

/// "Sött" in glossy candy lettering.
private struct Logo: View {
    var body: some View {
        VStack(spacing: -6) {
            Text("Sött")
                .font(Theme.title(54, weight: .black))
                .foregroundStyle(LinearGradient(colors: [Color(uiColor: Theme.accentUI.lighter(0.35)), Theme.accent,
                                                         Color(uiColor: Theme.candy(.purple))],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: .white, radius: 0, x: 2.5, y: 2.5)
                .shadow(color: .white, radius: 0, x: -2.5, y: -2.5)
                .shadow(color: .white, radius: 0, x: 2.5, y: -2.5)
                .shadow(color: .white, radius: 0, x: -2.5, y: 2.5)
                .shadow(color: Color(uiColor: Theme.candy(.purple).darker(0.3)).opacity(0.6), radius: 0, y: 5)
            Text("Bonbon-Puzzle")
                .font(Theme.title(14, weight: .heavy))
                .candyText(Color(uiColor: Theme.candy(.purple).darker(0.3)))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(uiColor: Theme.candy(.purple).lighter(0.1))))
        }
    }
}

/// Wooden-sign style banner that names each group of six levels.
private struct EpisodeSign: View {
    let number: Int

    private static let names = ["Bonbonwiese", "Schokotal", "Zuckerwolken", "Karamellküste"]

    var body: some View {
        VStack(spacing: 0) {
            Text("Episode \(number)")
                .font(Theme.title(11, weight: .heavy))
                .foregroundStyle(.white.opacity(0.9))
            Text(Self.names[(number - 1) % Self.names.count])
                .font(Theme.title(17, weight: .black))
                .candyText(Color(uiColor: Theme.candy(.purple).darker(0.35)))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [Color(uiColor: Theme.candy(.purple).lighter(0.25)),
                                              Color(uiColor: Theme.candy(.purple))],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Capsule().stroke(.white, lineWidth: 2.5))
                .shadow(color: Color(uiColor: Theme.candy(.purple).darker(0.4)), radius: 0, y: 4)
        )
    }
}

/// Winding path the level discs sit on.
struct MapPath: Shape {
    let count: Int
    let spacing: CGFloat

    static func offset(for index: Int) -> CGFloat {
        [0, 80, 110, 60, -30, -100, -95, -35][index % 8]
    }

    static func y(for index: Int, spacing: CGFloat) -> CGFloat {
        50 + CGFloat(index) * spacing
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard count > 0 else { return path }
        let points = (0..<count).map { i in
            CGPoint(x: rect.midX + Self.offset(for: i), y: rect.minY + Self.y(for: i, spacing: spacing))
        }
        path.move(to: points[0])
        for i in 1..<points.count {
            let a = points[i - 1]
            let b = points[i]
            path.addCurve(to: b, control1: CGPoint(x: a.x, y: (a.y + b.y) / 2),
                          control2: CGPoint(x: b.x, y: (a.y + b.y) / 2))
        }
        return path
    }
}

private struct LevelNode: View {
    let level: Level
    let stars: Int
    let unlocked: Bool
    let isCurrent: Bool
    let action: () -> Void

    @State private var bounce = false

    private var color: UIColor {
        guard unlocked else { return UIColor(hex: 0xA7B7CC) }
        let colors: [CandyColor] = [.red, .orange, .green, .blue, .purple, .yellow]
        return Theme.candy(colors[(level.id - 1) % colors.count])
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isCurrent {
                    PulseHalo(color: .white)
                        .frame(width: 150, height: 150)
                }
                GlossyCircle(color: color)
                    .frame(width: isCurrent ? 84 : 72, height: isCurrent ? 84 : 72)
                if unlocked {
                    Text("\(level.id)")
                        .font(Theme.title(isCurrent ? 34 : 29, weight: .black))
                        .candyText(Color(uiColor: color.darker(0.5)))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24, weight: .bold))
                        .candyText(Color(uiColor: color.darker(0.45)))
                }
                if unlocked && !isCurrent {
                    StarArc(stars: stars)
                        .offset(y: -50)
                }
                if isCurrent {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 34, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Theme.accent)
                        .shadow(color: Color(uiColor: Theme.accentUI.darker(0.4)), radius: 0, y: 3)
                        .offset(y: bounce ? -70 : -60)
                }
            }
            .frame(width: 100, height: 100)
        }
        .buttonStyle(CandyPressStyle())
        .disabled(!unlocked)
        .onAppear {
            guard isCurrent else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { bounce = true }
        }
        .accessibilityLabel("Level \(level.id), \(level.name), \(stars) Sterne")
    }
}

/// Three stars fanned over a level disc.
private struct StarArc: View {
    let stars: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: i == 1 ? 18 : 15, weight: .black))
                    .foregroundStyle(i < stars ? Theme.star : Color.white.opacity(0.75))
                    .shadow(color: i < stars ? .orange : Theme.bannerEdge.opacity(0.4), radius: 0, y: 1.5)
                    .rotationEffect(.degrees(Double(i - 1) * 18))
                    .offset(y: i == 1 ? -4 : 0)
            }
        }
    }
}

/// Card shown before a level starts: goals, moves and the best result so far.
struct LevelIntroView: View {
    let level: Level
    let stars: Int
    let onPlay: () -> Void
    let onClose: () -> Void

    var body: some View {
        CandyPanel(title: "Level \(level.id)") {
            VStack(spacing: 16) {
                Text(level.name)
                    .font(Theme.title(20, weight: .heavy))
                    .foregroundStyle(Theme.ink)

                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: i == 1 ? 46 : 36, weight: .black))
                            .foregroundStyle(i < stars ? Theme.star : Color(uiColor: UIColor(hex: 0xE3DCEF)))
                            .shadow(color: i < stars ? .orange : .gray.opacity(0.3), radius: 0, y: 3)
                            .offset(y: i == 1 ? -6 : 0)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(level.goals.enumerated()), id: \.offset) { _, goal in
                        HStack(spacing: 12) {
                            GoalIcon(goal: goal, size: 30)
                            Text(goal.summary)
                                .font(Theme.title(16, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    HStack(spacing: 12) {
                        Text("\(level.moves)")
                            .font(Theme.title(15, weight: .black))
                            .candyText()
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.banner))
                        Text("in \(level.moves) Zügen")
                            .font(Theme.title(16, weight: .bold))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: UIColor(hex: 0xEAF6FF))))

                CandyCapsuleButton(title: "Spielen", color: Theme.greenButtonUI, icon: "play.fill", action: onPlay)
            }
        }
        .overlay(alignment: .topTrailing) {
            CandyIconButton(symbol: "xmark", color: Theme.accentUI, label: "Schließen", size: 40, action: onClose)
                .offset(x: -4, y: -6)
        }
        .padding(24)
    }
}

struct SettingsView: View {
    @AppStorage(SettingsKey.sound) private var sound = true
    @AppStorage(SettingsKey.music) private var music = true
    @AppStorage(SettingsKey.voice) private var voice = true
    @AppStorage(SettingsKey.haptics) private var haptics = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Musik", isOn: $music)
                    Toggle("Soundeffekte", isOn: $sound)
                    Toggle("Stimme bei Kombos", isOn: $voice)
                    Toggle("Haptisches Feedback", isOn: $haptics)
                }
                Section {
                    Text("Tausche zwei benachbarte Bonbons, um drei oder mehr gleiche in eine Reihe zu bringen. Vier, fünf oder L-Formen ergeben Spezial-Bonbons. Übrige Züge werden am Ende zum Zuckerrausch.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            .tint(Theme.accent)
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: music) { _, _ in SoundManager.shared.updateMusic() }
        }
    }
}
