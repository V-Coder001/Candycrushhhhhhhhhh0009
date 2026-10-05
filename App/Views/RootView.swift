import Match3Core
import SwiftUI

/// Level map: a candy road winding down through the sky, one glossy disc per level.
struct RootView: View {
    @EnvironmentObject private var progress: ProgressStore
    @State private var playing: Level?
    @State private var intro: Level?
    @State private var showSettings = false
    @State private var showLab = false
    /// Extra moves taken on the start card for the level about to open.
    @State private var bonusMoves = 0

    /// Set when the puzzle is opened from the Klarkopf start screen: the gear becomes a close button.
    private let onClose: (() -> Void)?

    private static let spacing: CGFloat = 118
    private static let levelsPerEpisode = 6

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            CandyBackdrop()
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    // Lazy, one level at a time: the map has over a thousand levels.
                    LazyVStack(spacing: 0) {
                        header
                            .padding(.bottom, 80)
                        let current = currentLevel?.id
                        ForEach(Level.campaign) { level in
                            mapRow(level, isCurrent: level.id == current)
                                .id(level.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                }
                .onAppear {
                    guard let current = currentLevel else { return }
                    DispatchQueue.main.async { proxy.scrollTo(current.id, anchor: .center) }
                }
            }

            if let level = intro {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { closeIntro() }
                    .transition(.opacity)
                LevelIntroView(level: level, stars: progress.stars[level.id] ?? 0,
                               onPlay: { withExtraMoves in
                                   closeIntro()
                                   bonusMoves = withExtraMoves && progress.use(.extraMoves)
                                       ? Booster.extraMovesAmount : 0
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
            if Demo.lab { showLab = true }
        }
        .fullScreenCover(item: $playing) { level in
            GameView(level: level,
                     bonusMoves: bonusMoves,
                     onClose: {
                         bonusMoves = 0
                         playing = nil
                     },
                     onNext: nextAction(after: level))
                .id(level.id)
                .environmentObject(progress)
        }
        .sheet(isPresented: $showLab) {
            MixLabView { level in
                showLab = false
                open(level)
            }
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
        return {
            bonusMoves = 0
            playing = next
        }
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

            if let onClose {
                CandyIconButton(symbol: "xmark", color: Theme.accentUI, label: "Zurück zur Startseite", size: 46,
                                action: onClose)
            } else {
                CandyIconButton(symbol: "gearshape.fill", color: Theme.accentUI, label: "Einstellungen", size: 46) {
                    showSettings = true
                }
            }
        }
    }

    // MARK: Map

    /// One level disc with the stretch of candy road down to the next one, which is drawn on top of it.
    /// The first level of each episode also carries the episode sign.
    private func mapRow(_ level: Level, isCurrent: Bool) -> some View {
        let index = level.id - 1
        let isLast = level.id == Level.campaign.count
        let road = index...(isLast ? index : index + 1)
        return ZStack(alignment: .top) {
            // Candy road: a wide sugar-white band with pink stripes painted on.
            MapPath(indices: road, spacing: Self.spacing)
                .stroke(Color(uiColor: UIColor(hex: 0x1A4D8F, alpha: 0.18)),
                        style: StrokeStyle(lineWidth: 34, lineCap: .round, lineJoin: .round))
                .offset(y: 5)
            MapPath(indices: road, spacing: Self.spacing)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round))
            MapPath(indices: road, spacing: Self.spacing)
                .stroke(Color(uiColor: Theme.accentUI.lighter(0.25)),
                        style: StrokeStyle(lineWidth: 12, lineCap: .butt, lineJoin: .round, dash: [12, 14]))

            LevelNode(level: level,
                      stars: progress.stars[level.id] ?? 0,
                      unlocked: progress.isUnlocked(level),
                      isCurrent: isCurrent) {
                open(level)
            }
            .offset(x: MapPath.offset(for: index), y: MapPath.y(for: 0, spacing: Self.spacing) - 50)

            if index % Self.levelsPerEpisode == 0 {
                EpisodeSign(number: index / Self.levelsPerEpisode + 1)
                    .offset(y: MapPath.y(for: 0, spacing: Self.spacing) - 108)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.spacing + (isLast ? 80 : 0), alignment: .top)
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

    private static let names = ["Bonbonwiese", "Schokotal", "Zuckerwolken", "Karamellküste", "Lakritzwald",
                                "Marzipanberge", "Brausebucht", "Nougatinsel", "Honigtal", "Kaugummiwolken",
                                "Waffelwüste", "Lollihain"]

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

/// Winding path the level discs sit on. Draws the stretch between the given levels; the first one sits at
/// the top of the shape.
struct MapPath: Shape {
    let indices: ClosedRange<Int>
    let spacing: CGFloat

    static func offset(for index: Int) -> CGFloat {
        [0, 80, 110, 60, -30, -100, -95, -35][index % 8]
    }

    static func y(for index: Int, spacing: CGFloat) -> CGFloat {
        50 + CGFloat(index) * spacing
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = indices.map { i in
            CGPoint(x: rect.midX + Self.offset(for: i),
                    y: rect.minY + Self.y(for: i - indices.lowerBound, spacing: spacing))
        }
        guard let start = points.first else { return path }
        path.move(to: start)
        for (a, b) in zip(points, points.dropFirst()) {
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
        .accessibilityLabel("\(level.title), \(level.name), \(stars) Sterne")
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

/// Card shown before a level starts: goals, moves, the best result so far and the boosters.
struct LevelIntroView: View {
    let level: Level
    let stars: Int
    /// Starts the level; true if the player takes the extra moves booster along.
    let onPlay: (_ withExtraMoves: Bool) -> Void
    let onClose: () -> Void

    @EnvironmentObject private var progress: ProgressStore
    @State private var takeExtraMoves = false

    private var moves: Int { level.moves + (takeExtraMoves ? Booster.extraMovesAmount : 0) }

    var body: some View {
        CandyPanel(title: level.title) {
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
                        Text("\(moves)")
                            .font(Theme.title(15, weight: .black))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .candyText()
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.banner))
                        Text("in \(moves) Zügen")
                            .font(Theme.title(16, weight: .bold))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: UIColor(hex: 0xEAF6FF))))

                boosterPicker

                CandyCapsuleButton(title: "Spielen", color: Theme.greenButtonUI, icon: "play.fill") {
                    onPlay(takeExtraMoves)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            CandyIconButton(symbol: "xmark", color: Theme.accentUI, label: "Schließen", size: 40, action: onClose)
                .offset(x: -4, y: -6)
        }
        .padding(24)
    }
}

extension LevelIntroView {
    /// Extra moves can be taken along now; hammer and colour mixer wait for the level.
    private var boosterPicker: some View {
        let extra = progress.count(of: .extraMoves)
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                guard extra > 0 else { return }
                withAnimation(.snappy) { takeExtraMoves.toggle() }
            } label: {
                HStack(spacing: 12) {
                    BoosterBadge(booster: .extraMoves, size: 34, enabled: extra > 0)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("+\(Booster.extraMovesAmount) Züge zum Start")
                            .font(Theme.title(16, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(extra > 0 ? "noch \(extra)" : "keine mehr übrig")
                            .font(Theme.title(13, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: takeExtraMoves ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(takeExtraMoves ? Theme.greenButton : Theme.muted.opacity(0.5))
                }
            }
            .buttonStyle(CandyPressStyle())
            .disabled(extra == 0)
            .accessibilityAddTraits(takeExtraMoves ? .isSelected : [])

            HStack(spacing: 8) {
                ForEach([Booster.hammer, .colorMixer]) { booster in
                    HStack(spacing: 4) {
                        Image(systemName: booster.symbol)
                            .foregroundStyle(Color(uiColor: booster.color))
                        Text("\(progress.count(of: booster))")
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                    }
                    .font(Theme.title(14, weight: .heavy))
                }
                Text("im Level einsetzbar")
                    .font(Theme.title(13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(uiColor: UIColor(hex: 0xEFFBEF))))
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
