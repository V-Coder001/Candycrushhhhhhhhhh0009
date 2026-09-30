import Match3Core
import SwiftUI

/// Pressable candy look: sinks a little while held and clicks when released.
struct CandyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if !pressed { SoundManager.shared.tap() }
            }
    }
}

/// Wide glossy pill button ("Spielen", "Weiter").
struct CandyCapsuleButton: View {
    let title: String
    let color: UIColor
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 18, weight: .black))
                }
                Text(title).font(Theme.title(21, weight: .black))
            }
            .candyText(Color(uiColor: color.darker(0.45)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    Capsule().fill(Color(uiColor: color.darker(0.35))).offset(y: 5)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(uiColor: color.lighter(0.35)), Color(uiColor: color)],
                                             startPoint: .top, endPoint: .bottom))
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)],
                                             startPoint: .top, endPoint: .center))
                        .padding(.horizontal, 14)
                        .padding(.top, 3)
                        .padding(.bottom, 18)
                    Capsule().stroke(.white, lineWidth: 3)
                }
            )
        }
        .buttonStyle(CandyPressStyle())
    }
}

/// Round glossy icon button (close, restart, settings).
struct CandyIconButton: View {
    let symbol: String
    let color: UIColor
    let label: String
    var size: CGFloat = 50
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .black))
                .candyText(Color(uiColor: color.darker(0.45)))
                .frame(width: size, height: size)
                .background(GlossyCircle(color: color))
        }
        .buttonStyle(CandyPressStyle())
        .accessibilityLabel(label)
    }
}

/// White card with a candy-pink rim and a ribbon title.
struct CandyPanel<Content: View>: View {
    let title: String
    var ribbon: UIColor = Theme.accentUI
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 16) {
            Ribbon(text: title, color: ribbon)
                .offset(y: -38)
                .padding(.bottom, -38)
            content
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 24)
        .frame(maxWidth: 350)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(LinearGradient(colors: [.white, Color(uiColor: UIColor(hex: 0xFFEFF8))],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [Color(uiColor: ribbon.lighter(0.5)),
                                                              Color(uiColor: ribbon.lighter(0.2))],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 5)
                )
                .shadow(color: Color(uiColor: ribbon.darker(0.5)).opacity(0.35), radius: 0, y: 6)
                .shadow(color: .black.opacity(0.2), radius: 18, y: 10)
        )
    }
}

/// Folded ribbon banner used as a panel title.
struct Ribbon: View {
    let text: String
    let color: UIColor

    var body: some View {
        Text(text)
            .font(Theme.title(26, weight: .black))
            .candyText(Color(uiColor: color.darker(0.45)))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RibbonShape()
                        .fill(Color(uiColor: color.darker(0.3)))
                        .offset(y: 5)
                    RibbonShape()
                        .fill(LinearGradient(colors: [Color(uiColor: color.lighter(0.3)), Color(uiColor: color)],
                                             startPoint: .top, endPoint: .bottom))
                    RibbonShape().stroke(.white, lineWidth: 3)
                }
            )
    }
}

private struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = rect.height * 0.35
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// Shiny round button, like a hard candy.
struct GlossyCircle: View {
    let color: UIColor

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: color.darker(0.4)))
                .offset(y: 4)
            Circle()
                .fill(RadialGradient(colors: [Color(uiColor: color.lighter(0.45)), Color(uiColor: color),
                                              Color(uiColor: color.darker(0.25))],
                                     center: UnitPoint(x: 0.4, y: 0.3), startRadius: 1, endRadius: 44))
            Circle().stroke(.white, lineWidth: 3)
            GeometryReader { geo in
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.05)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: geo.size.width * 0.58, height: geo.size.height * 0.3)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.26)
            }
        }
        .shadow(color: Color(uiColor: color.darker(0.5)).opacity(0.35), radius: 4, y: 4)
    }
}

/// Goal icon and a short German description, shared by the HUD and the level intro.
struct GoalIcon: View {
    let goal: Goal
    var size: CGFloat = 26

    var body: some View {
        switch goal {
        case .score:
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.78, weight: .bold))
                .foregroundStyle(Theme.star)
                .shadow(color: .orange, radius: 0, y: 1.5)
                .frame(width: size, height: size)
        case .clearJelly:
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(LinearGradient(colors: [Color(uiColor: Theme.jellyUI.lighter(0.3)), Theme.jelly],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).stroke(.white, lineWidth: 1.5))
                .frame(width: size * 0.85, height: size * 0.85)
                .frame(width: size, height: size)
        case .collectIngredients:
            Image(uiImage: CandyArt.shared.image(for: .ingredient(.cherry), size: size))
        case .clearChocolate:
            Image(uiImage: CandyArt.shared.image(for: .chocolate, size: size))
        case .serveMixes:
            Image(uiImage: CandyArt.shared.image(for: .mix(.red, .yellow), size: size))
        }
    }
}

extension Level {
    /// "Level 12", or "Labor 3" for the Mischlabor.
    var title: String {
        id >= Level.mixLabFirstID ? "Labor \(id - Level.mixLabFirstID + 1)" : "Level \(id)"
    }
}

extension Goal {
    var summary: String {
        switch self {
        case let .score(points): return "Erreiche \(points.formatted()) Punkte"
        case .clearJelly: return "Entferne das ganze Gelee"
        case let .collectIngredients(count): return "Bring \(count) Zutaten nach unten"
        case .clearChocolate: return "Räume die Schokolade ab"
        case let .serveMixes(count): return "Mische und serviere \(count) Mischbonbons"
        }
    }
}

/// Confetti rain for won levels.
struct ConfettiView: View {
    private struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let sway: Double
        let spin: Double
        let size: CGSize
        let color: Color
        let round: Bool
    }

    private let pieces: [Piece] = (0..<90).map { i in
        let colors: [CandyColor] = [.red, .orange, .yellow, .green, .blue, .purple]
        return Piece(x: Double.random(in: 0...1), delay: Double.random(in: 0...1.2),
                     speed: Double.random(in: 0.28...0.5), sway: Double.random(in: 8...26),
                     spin: Double.random(in: 2...7), size: CGSize(width: Double.random(in: 7...12),
                                                                    height: Double.random(in: 10...18)),
                     color: Color(uiColor: Theme.candy(colors[i % colors.count])), round: i % 5 == 0)
    }
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let y = -20 + t * piece.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(t * 2.4 + piece.x * 9) * piece.sway
                    var ctx = context
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(t * piece.spin))
                    ctx.scaleBy(x: cos(t * piece.spin * 0.8), y: 1)
                    let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2,
                                      width: piece.size.width, height: piece.round ? piece.size.width : piece.size.height)
                    let path = piece.round ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 2)
                    ctx.fill(path, with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// Soft pulsing glow, used to mark the next level on the map.
struct PulseHalo: View {
    let color: Color
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.7), color.opacity(0)], center: .center,
                                 startRadius: 10, endRadius: 70))
            .scaleEffect(pulse ? 1.15 : 0.85)
            .opacity(pulse ? 0.9 : 0.5)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
            }
            .allowsHitTesting(false)
    }
}

// MARK: Boosters

/// Round booster icon in its candy colour.
struct BoosterBadge: View {
    let booster: Booster
    var size: CGFloat = 56
    var enabled = true

    var body: some View {
        let color = enabled ? booster.color : UIColor(hex: 0xA7B7CC)
        Image(systemName: booster.symbol)
            .font(.system(size: size * 0.4, weight: .black))
            .candyText(Color(uiColor: color.darker(0.45)))
            .frame(width: size, height: size)
            .background(GlossyCircle(color: color))
    }
}

/// Booster in the game's bottom bar, with how many are left.
struct BoosterButton: View {
    let booster: Booster
    let count: Int
    var active = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BoosterBadge(booster: booster, enabled: count > 0)
                .overlay(Circle().stroke(Color.white, lineWidth: active ? 4 : 0).padding(-5))
                .scaleEffect(active ? 1.12 : 1)
                .overlay(alignment: .topTrailing) {
                    Text("\(count)")
                        .font(Theme.title(13, weight: .black))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(Circle().fill(count > 0 ? Theme.accent : Color(uiColor: UIColor(hex: 0x8C9AAE))))
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 6, y: -4)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: active)
        }
        .buttonStyle(CandyPressStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
        .accessibilityLabel("\(booster.title), noch \(count)")
        .accessibilityHint(booster.explanation)
    }
}

/// Shown over the board while the hammer is picked up.
struct HammerHint: View {
    var body: some View {
        Label("Tippe auf ein Feld", systemImage: "hammer.fill")
            .font(Theme.title(15, weight: .heavy))
            .candyText(Color(uiColor: Booster.hammer.color.darker(0.45)))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color(uiColor: Booster.hammer.color))
                    .overlay(Capsule().stroke(.white, lineWidth: 2.5))
                    .shadow(color: Color(uiColor: Booster.hammer.color.darker(0.4)), radius: 0, y: 3)
            )
    }
}

/// Short "+5 Züge" pop-up under the moves counter.
struct BoosterToast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.title(22, weight: .black))
            .candyText(Color(uiColor: Booster.extraMoves.color.darker(0.45)))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color(uiColor: Booster.extraMoves.color))
                    .overlay(Capsule().stroke(.white, lineWidth: 2.5))
            )
    }
}
