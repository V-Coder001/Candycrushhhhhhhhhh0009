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
            case .blocks: return UIColor(hex: 0xFF8A14)
            case .twenty48: return UIColor(hex: 0xFFC727)
            case .solitaire: return UIColor(hex: 0x2FBF45)
            case .chess: return UIColor(hex: 0x8B5E3C)
            }
        }
    }

    init() {}

    var body: some View {
        ZStack {
            CandyBackdrop()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    HStack {
                        Color.clear.frame(width: 46, height: 46)
                        Spacer()
                        Logo()
                        Spacer()
                        CandyIconButton(symbol: "gearshape.fill", color: Theme.accentUI, label: "Einstellungen",
                                        size: 46) { showSettings = true }
                    }
                    Text("Spielesammlung")
                        .font(Theme.title(22, weight: .black))
                        .candyText()
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                              spacing: 14) {
                        ForEach(CasualGame.allCases) { game in
                            Button { open = game } label: { tile(game) }
                                .buttonStyle(CandyPressStyle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.light)
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

    private func tile(_ game: CasualGame) -> some View {
        VStack(spacing: 10) {
            icon(game)
                .frame(width: 84, height: 84)
            Text(game.title)
                .font(Theme.title(19, weight: .black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(record(game))
                .font(Theme.title(13, weight: .bold))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.white)
                .shadow(color: Color(uiColor: game.color.darker(0.4)).opacity(0.35), radius: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color(uiColor: game.color.lighter(0.2)), lineWidth: 3)
        )
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
                .shadow(color: Color(uiColor: UIColor(hex: 0xB07400)), radius: 0, y: 3)
        case .solitaire:
            ZStack {
                miniCard("♠", red: false).rotationEffect(.degrees(-12)).offset(x: -14)
                miniCard("♥", red: true).rotationEffect(.degrees(10)).offset(x: 14)
            }
        case .chess:
            Text("\u{265E}\u{FE0E}")
                .font(.system(size: 64))
                .foregroundStyle(Color(uiColor: UIColor(hex: 0x3E2A1A)))
                .frame(width: 80, height: 80)
                .background(Circle().fill(Color(uiColor: UIColor(hex: 0xF0D9B5))))
                .overlay(Circle().stroke(Color(uiColor: UIColor(hex: 0xB58863)), lineWidth: 4))
        }
    }

    private func miniBlock(_ hex: UInt32) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LinearGradient(colors: [Color(uiColor: UIColor(hex: hex).lighter(0.3)), Color(uiColor: UIColor(hex: hex))],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 24, height: 24)
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
