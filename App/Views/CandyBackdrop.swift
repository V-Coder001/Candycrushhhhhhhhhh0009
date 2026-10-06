import SwiftUI

/// Neon candy night: a deep violet sky with drifting aurora glows, twinkling sugar stars,
/// floating candy orbs and a glowing grid floor.
struct CandyBackdrop: View {
    /// Main glow colour; each game tints its own backdrop.
    var accent: Color = Theme.neonPink
    var secondary: Color = Theme.neonCyan

    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(colors: [Theme.nightTop, Theme.nightMid, Theme.nightBottom],
                               startPoint: .top, endPoint: .bottom)

                glow(accent, size: w * 1.3, opacity: 0.5)
                    .position(x: w * (drift ? 0.12 : 0.3), y: h * (drift ? 0.1 : 0.16))
                glow(secondary, size: w * 1.1, opacity: 0.32)
                    .position(x: w * (drift ? 1.0 : 0.82), y: h * (drift ? 0.48 : 0.4))
                glow(Theme.neonViolet, size: w * 1.4, opacity: 0.55)
                    .position(x: w * (drift ? 0.35 : 0.55), y: h * 0.86)

                SugarStars()
                    .opacity(drift ? 1 : 0.6)

                NeonGrid()
                    .stroke(accent.opacity(0.55), lineWidth: 1)
                    .shadow(color: accent, radius: 4)
                    .mask(LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                    .frame(width: w, height: h * 0.3)
                    .position(x: w / 2, y: h * 0.85)

                ForEach(Self.orbs.indices, id: \.self) { i in
                    let orb = Self.orbs[i]
                    CandyOrb(color: orb.color, size: orb.size)
                        .position(x: w * orb.x, y: h * orb.y + (drift ? -orb.float : orb.float))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { drift = true }
        }
        .accessibilityHidden(true)
    }

    private func glow(_ color: Color, size: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(opacity), color.opacity(0)], center: .center,
                                 startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
    }

    private static let orbs: [(x: CGFloat, y: CGFloat, size: CGFloat, float: CGFloat, color: UIColor)] = [
        (0.08, 0.3, 18, 8, Theme.neonPinkUI),
        (0.92, 0.18, 12, 6, Theme.neonCyanUI),
        (0.86, 0.66, 22, 10, Theme.neonVioletUI),
        (0.12, 0.74, 14, 7, Theme.starUI),
        (0.55, 0.06, 10, 5, Theme.neonMintUI),
    ]
}

/// Small glossy candy ball with a glow, floating in the backdrop.
private struct CandyOrb: View {
    let color: UIColor
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(uiColor: color.lighter(0.6)), Color(uiColor: color),
                                          Color(uiColor: color.darker(0.35))],
                                 center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.7))
            .frame(width: size, height: size)
            .shadow(color: Color(uiColor: color).opacity(0.9), radius: size * 0.6)
            .opacity(0.85)
    }
}

/// Fixed scatter of tiny stars; positions come from a simple hash so they stay put between frames.
private struct SugarStars: View {
    var body: some View {
        Canvas { context, size in
            for i in 0..<70 {
                let x = CGFloat((i * 7919) % 1000) / 1000 * size.width
                let y = CGFloat((i * 104_729) % 1000) / 1000 * size.height * 0.8
                let r = 0.6 + CGFloat((i * 31) % 10) / 8
                let alpha = 0.25 + Double((i * 17) % 10) / 14
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(alpha)))
            }
        }
    }
}

/// Synthwave floor: lines running to a vanishing point above the top edge, rows closing up toward the horizon.
private struct NeonGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let vanishX = rect.midX
        // The vanishing point sits 0.6 heights above the top, so lines cover 1 / 1.6 of their run.
        let t: CGFloat = 1 / 1.6
        for i in -10...10 {
            let bottomX = rect.midX + CGFloat(i) * rect.width / 7
            path.move(to: CGPoint(x: bottomX + (vanishX - bottomX) * t, y: rect.minY))
            path.addLine(to: CGPoint(x: bottomX, y: rect.maxY))
        }
        for j in 0..<9 {
            let f = CGFloat(j) / 8
            let y = rect.minY + rect.height * f * f
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}
