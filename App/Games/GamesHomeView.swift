import Match3Core
import SwiftUI
import UIKit

/// Sött start screen: a collection of relaxed classics, each on its own tile.
struct GamesHomeView: View {
    @EnvironmentObject private var progress: ProgressStore
    @AppStorage("best.2048") private var best2048 = 0
    @AppStorage("best.blocks") private var bestBlocks = 0
    @AppStorage("wins.solitaire") private var solitaireWins = 0
    @AppStorage("wins.chess") private var chessWins = 0
    @State private var open: CasualGame?
    @State private var showSettings = false

    enum CasualGame: String, CaseIterable, Identifiable {
        case candy, blocks, twenty48, solitaire, chess

        var id: String { rawValue }

        var title: String {
            switch self {
            case .candy: return "Bonbon-Puzzle"
            case .blocks: return "Block-Puzzle"
            case .twenty48: return "2048"
            case .solitaire: return "Solitär"
            case .chess: return "Schach"
            }
        }

        var color: UIColor {
            switch self {
            case .candy: return Theme.accentUI
            case .blocks: return Theme.neonCyanUI
            case .twenty48: return Theme.neonAmberUI
            case .solitaire: return Theme.neonMintUI
            case .chess: return Theme.neonVioletUI
            }
        }
    }

    init() {}

    var body: some View {
        ZStack {
            CandyBackdrop()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center) {
                        Logo(subtitle: "Spielesammlung")
                        Spacer()
                        CandyIconButton(symbol: "gearshape.fill", color: Theme.neonVioletUI, label: "Einstellungen",
                                        size: 46) { showSettings = true }
                    }
                    Text("Was spielen wir heute?")
                        .font(Theme.title(17, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, -6)

                    Button { open = .candy } label: { hero }
                        .buttonStyle(CandyPressStyle())

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                              spacing: 14) {
                        ForEach(CasualGame.allCases.filter { $0 != .candy }) { game in
                            Button { open = game } label: { tile(game) }
                                .buttonStyle(CandyPressStyle())
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $open) { game in
            screen(for: game)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium])
        }
        .onAppear(perform: openDemo)
    }

    @ViewBuilder
    private func screen(for game: CasualGame) -> some View {
        let close = {
            open = nil
            SoundManager.shared.stopMusic()
        }
        switch game {
        case .candy: RootView(onClose: close).environmentObject(progress)
        case .blocks: BlockPuzzleView(onClose: close)
        case .twenty48: Twenty48View(onClose: close)
        case .solitaire: SolitaireView(onClose: close)
        case .chess: ChessView(onClose: close)
        }
    }

    // MARK: Tiles

    /// Big card for the candy puzzle, the heart of the collection.
    private var hero: some View {
        let color = Color(uiColor: CasualGame.candy.color)
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("LEVEL \(currentLevelNumber)")
                    .font(Theme.title(12, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(Theme.neonCyan)
                Text(CasualGame.candy.title)
                    .font(Theme.title(28, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(record(.candy))
                    .font(Theme.title(14, weight: .bold))
                    .foregroundStyle(Theme.muted)
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("Weiterspielen")
                }
                .font(Theme.title(15, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [Color(uiColor: Theme.neonPinkUI.lighter(0.2)), Theme.neonPink],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                        .shadow(color: Theme.neonPink.opacity(0.8), radius: 10)
                )
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [color.opacity(0.7), color.opacity(0)], center: .center,
                                         startRadius: 0, endRadius: 80))
                    .frame(width: 160, height: 160)
                Image(uiImage: CandyArt.shared.image(for: .plain(.purple), size: 54))
                    .rotationEffect(.degrees(18))
                    .offset(x: -42, y: 34)
                Image(uiImage: CandyArt.shared.image(for: .plain(.yellow), size: 46))
                    .rotationEffect(.degrees(-20))
                    .offset(x: 40, y: -40)
                Image(uiImage: CandyArt.shared.image(for: .plain(.red), size: 100))
                    .rotationEffect(.degrees(-12))
                    .shadow(color: color.opacity(0.9), radius: 18)
            }
            .frame(width: 130, height: 130)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 30, tint: color, glow: 0.45)
        .accessibilityElement(children: .combine)
    }

    private var currentLevelNumber: Int {
        Level.campaign.last { progress.isUnlocked($0) }?.id ?? 1
    }

    private func tile(_ game: CasualGame) -> some View {
        let color = Color(uiColor: game.color)
        return VStack(alignment: .leading, spacing: 10) {
            icon(game)
                .frame(width: 84, height: 84)
                .frame(maxWidth: .infinity)
                .background(
                    Circle()
                        .fill(RadialGradient(colors: [color.opacity(0.55), color.opacity(0)], center: .center,
                                             startRadius: 0, endRadius: 60))
                        .frame(width: 130, height: 130)
                )
                .padding(.vertical, 6)
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.title)
                        .font(Theme.title(19, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(record(game))
                        .font(Theme.title(13, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 2)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(color.opacity(0.85)).shadow(color: color, radius: 6))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 26, tint: color, glow: 0.3)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func icon(_ game: CasualGame) -> some View {
        switch game {
        case .candy:
            Image(uiImage: CandyArt.shared.image(for: .plain(.red), size: 84))
        case .blocks:
            VStack(spacing: 3) {
                HStack(spacing: 3) { miniBlock(0xF0303A); miniBlock(0xFF8A14); miniBlock(0xFFC727) }
                HStack(spacing: 3) { miniBlock(0x228BF2); Color.clear.frame(width: 24, height: 24); miniBlock(0x2FBF45) }
                HStack(spacing: 3) { miniBlock(0xA13FE0); miniBlock(0xFF4FA3); miniBlock(0x228BF2) }
            }
        case .twenty48:
            Text("2048")
                .font(Theme.title(24, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [Color(uiColor: UIColor(hex: 0xFFD866)), Color(uiColor: UIColor(hex: 0xFFB020))],
                                         startPoint: .top, endPoint: .bottom)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
                .shadow(color: Theme.neonAmber.opacity(0.8), radius: 12)
        case .solitaire:
            ZStack {
                miniCard("♠", red: false).rotationEffect(.degrees(-12)).offset(x: -14)
                miniCard("♥", red: true).rotationEffect(.degrees(10)).offset(x: 14)
            }
        case .chess:
            Text("\u{265E}\u{FE0E}")
                .font(.system(size: 60))
                .foregroundStyle(LinearGradient(colors: [.white, Color(uiColor: Theme.neonVioletUI.lighter(0.5))],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.neonViolet, radius: 10)
                .frame(width: 80, height: 80)
                .background(Circle().fill(Color(uiColor: UIColor(hex: 0x2A1668))))
                .overlay(Circle().strokeBorder(LinearGradient(colors: [Theme.neonCyan, Theme.neonViolet],
                                                              startPoint: .top, endPoint: .bottom), lineWidth: 2.5))
                .shadow(color: Theme.neonViolet.opacity(0.8), radius: 10)
        }
    }

    private func miniBlock(_ hex: UInt32) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LinearGradient(colors: [Color(uiColor: UIColor(hex: hex).lighter(0.3)), Color(uiColor: UIColor(hex: hex))],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 24, height: 24)
            .shadow(color: Color(uiColor: UIColor(hex: hex)).opacity(0.8), radius: 5)
    }

    private func miniCard(_ suit: String, red: Bool) -> some View {
        Text(suit)
            .font(.system(size: 30))
            .foregroundStyle(red ? Color(uiColor: UIColor(hex: 0xD62B36)) : Color(uiColor: UIColor(hex: 0x1E1E28)))
            .frame(width: 46, height: 64)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.gray.opacity(0.4), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }

    private func record(_ game: CasualGame) -> String {
        switch game {
        case .candy: return "\(progress.totalStars) Sterne"
        case .blocks: return bestBlocks > 0 ? "Rekord \(formatPoints(bestBlocks))" : "Noch kein Rekord"
        case .twenty48: return best2048 > 0 ? "Rekord \(formatPoints(best2048))" : "Noch kein Rekord"
        case .solitaire: return solitaireWins == 1 ? "1 Sieg" : "\(solitaireWins) Siege"
        case .chess: return chessWins == 1 ? "1 Sieg" : "\(chessWins) Siege"
        }
    }

    /// Screenshots: `-demoScreen candy|blocks|2048|solitaire|chess`; Bonbon demos open the puzzle.
    private func openDemo() {
        switch Demo.screen {
        case "candy": open = .candy
        case "blocks": open = .blocks
        case "2048": open = .twenty48
        case "solitaire": open = .solitaire
        case "chess": open = .chess
        default:
            if Demo.level != nil || Demo.intro != nil || Demo.lab { open = .candy }
        }
    }
}
