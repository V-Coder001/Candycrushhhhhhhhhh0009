import Match3Core
import SwiftUI

/// Level map: candy buttons along a winding path over the sky backdrop.
struct RootView: View {
    @EnvironmentObject private var progress: ProgressStore
    @State private var playing: Level?
    @State private var showSettings = false

    var body: some View {
        ZStack {
            CandyBackdrop()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    ZStack {
                        MapPath(count: Level.campaign.count, spacing: 104)
                            .stroke(Color.white.opacity(0.85),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round, dash: [2, 16]))
                        VStack(spacing: 4) {
                            ForEach(Level.campaign) { level in
                                LevelButton(level: level,
                                            stars: progress.stars[level.id] ?? 0,
                                            unlocked: progress.isUnlocked(level)) {
                                    playing = level
                                }
                                .offset(x: MapPath.offset(for: level.id - 1))
                            }
                        }
                    }
                    .padding(.bottom, 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            if playing == nil, let level = Demo.level { playing = level }
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

    private func nextAction(after level: Level) -> (() -> Void)? {
        guard let next = progress.nextLevel(after: level) else { return nil }
        return { playing = next }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Theme.star)
                    .shadow(color: .orange.opacity(0.6), radius: 0, y: 1.5)
                Text("\(progress.totalStars)")
                    .candyText()
            }
            .font(Theme.title(18))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.banner).overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 2)))

            Spacer()
            VStack(spacing: -4) {
                Text("Sött")
                    .font(Theme.title(52, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [Color(uiColor: Theme.accentUI.lighter(0.25)), Theme.accent,
                                                             Color(uiColor: Theme.candy(.purple))],
                                                    startPoint: .top, endPoint: .bottom))
                    .shadow(color: .white, radius: 0, x: 2, y: 2)
                    .shadow(color: .white, radius: 0, x: -2, y: -2)
                    .shadow(color: .white, radius: 0, x: 2, y: -2)
                    .shadow(color: .white, radius: 0, x: -2, y: 2)
                    .shadow(color: Theme.bannerEdge.opacity(0.5), radius: 4, y: 4)
                Text("Bonbon-Puzzle")
                    .font(Theme.title(15))
                    .candyText()
            }
            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .bold))
                    .candyText()
                    .frame(width: 46, height: 46)
                    .background(GlossyCircle(color: Theme.accentUI))
            }
            .accessibilityLabel("Einstellungen")
        }
    }
}

/// Zig-zag path the level buttons sit on.
private struct MapPath: Shape {
    let count: Int
    let spacing: CGFloat

    static func offset(for index: Int) -> CGFloat {
        [0, 70, 90, 30, -50, -90, -60][index % 7]
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard count > 0 else { return path }
        let points = (0..<count).map { i in
            CGPoint(x: rect.midX + Self.offset(for: i), y: rect.minY + 39 + CGFloat(i) * spacing)
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

/// Shiny round button, like a hard candy.
struct GlossyCircle: View {
    let color: UIColor

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(uiColor: color.lighter(0.45)), Color(uiColor: color),
                                          Color(uiColor: color.darker(0.3))],
                                 center: UnitPoint(x: 0.4, y: 0.3), startRadius: 1, endRadius: 40))
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .overlay(
                Ellipse()
                    .fill(.white.opacity(0.55))
                    .scaleEffect(x: 0.55, y: 0.28)
                    .offset(y: -12)
            )
            .shadow(color: Color(uiColor: color.darker(0.5)).opacity(0.45), radius: 3, y: 3)
    }
}

private struct LevelButton: View {
    let level: Level
    let stars: Int
    let unlocked: Bool
    let action: () -> Void

    private var color: UIColor {
        guard unlocked else { return UIColor(hex: 0x9FB3C8) }
        let colors: [CandyColor] = [.red, .orange, .green, .blue, .purple, .yellow]
        return Theme.candy(colors[(level.id - 1) % colors.count])
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    GlossyCircle(color: color)
                        .frame(width: 78, height: 78)
                    if unlocked {
                        Text("\(level.id)")
                            .font(Theme.title(30, weight: .black))
                            .candyText(Color(uiColor: color.darker(0.45)))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24, weight: .bold))
                            .candyText(Color(uiColor: color.darker(0.45)))
                    }
                }
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(i < stars ? Theme.star : Color.white.opacity(0.7))
                            .shadow(color: Theme.bannerEdge.opacity(0.5), radius: 0, y: 1)
                    }
                }
                .opacity(unlocked ? 1 : 0)
            }
            .frame(height: 100, alignment: .top)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel("Level \(level.id), \(level.name), \(stars) Sterne")
    }
}

struct SettingsView: View {
    @AppStorage(SettingsKey.sound) private var sound = true
    @AppStorage(SettingsKey.voice) private var voice = true
    @AppStorage(SettingsKey.haptics) private var haptics = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Soundeffekte", isOn: $sound)
                    Toggle("Stimme bei Kombos", isOn: $voice)
                    Toggle("Haptisches Feedback", isOn: $haptics)
                }
                Section {
                    Text("Tausche zwei benachbarte Bonbons, um drei oder mehr gleiche in eine Reihe zu bringen. Vier, fünf oder L-Formen ergeben Spezial-Bonbons.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            .tint(Theme.accent)
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
