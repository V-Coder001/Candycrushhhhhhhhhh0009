import SwiftUI

/// Sky with drifting clouds, chocolate hills and a pink candy sea.
struct CandyBackdrop: View {
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(colors: [Theme.skyTop, Theme.skyBottom], startPoint: .top, endPoint: .bottom)

                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.7), .white.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: w * 0.45))
                    .frame(width: w * 0.9, height: w * 0.9)
                    .position(x: w * 0.5, y: h * 0.18)

                Group {
                    Cloud().frame(width: w * 0.55, height: w * 0.2).position(x: w * 0.18, y: h * 0.1)
                    Cloud().frame(width: w * 0.45, height: w * 0.16).position(x: w * 0.85, y: h * 0.2)
                    Cloud().frame(width: w * 0.5, height: w * 0.18).position(x: w * 0.25, y: h * 0.42)
                    Cloud().frame(width: w * 0.4, height: w * 0.15).position(x: w * 0.9, y: h * 0.55)
                }
                .offset(x: drift ? 14 : -14)

                // Chocolate hills with icing.
                Hill()
                    .fill(LinearGradient(colors: [Color(red: 0.55, green: 0.3, blue: 0.18),
                                                  Color(red: 0.36, green: 0.18, blue: 0.1)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.7, height: h * 0.2)
                    .position(x: w * 0.1, y: h * 0.8)
                Hill()
                    .fill(LinearGradient(colors: [Color(red: 0.6, green: 0.34, blue: 0.2),
                                                  Color(red: 0.4, green: 0.2, blue: 0.12)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.8, height: h * 0.24)
                    .position(x: w * 0.95, y: h * 0.8)

                // Pink candy sea.
                Wave(phase: drift ? 0.6 : 0)
                    .fill(LinearGradient(colors: [Theme.seaLight, Theme.sea], startPoint: .top, endPoint: .bottom))
                    .frame(height: h * 0.2)
                    .position(x: w / 2, y: h * 0.9 + 4)

                ForEach(0..<9, id: \.self) { i in
                    let x = w * CGFloat((i * 37) % 100) / 100
                    let size = CGFloat(8 + (i * 7) % 14)
                    Circle()
                        .fill(Color.white.opacity(0.45))
                        .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                        .frame(width: size, height: size)
                        .position(x: x, y: h * (0.88 + CGFloat(i % 4) * 0.025) - (drift ? 6 : 0))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { drift = true }
        }
        .accessibilityHidden(true)
    }
}

private struct Cloud: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Capsule().frame(width: w, height: h * 0.55).offset(y: h * 0.2)
                Circle().frame(width: h * 0.8).offset(x: -w * 0.18, y: 0)
                Circle().frame(width: h).offset(x: w * 0.08, y: -h * 0.1)
                Circle().frame(width: h * 0.65).offset(x: w * 0.3, y: h * 0.08)
            }
            .frame(width: w, height: h)
            .foregroundStyle(.white.opacity(0.92))
            .shadow(color: Theme.bannerBottom.opacity(0.15), radius: 6, y: 4)
        }
    }
}

private struct Hill: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                      control1: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY - rect.height * 0.2),
                      control2: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY - rect.height * 0.2))
        path.closeSubpath()
        return path
    }
}

private struct Wave: Shape {
    var phase: CGFloat
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 10))
        let steps = 40
        for i in 0...steps {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(steps)
            let y = rect.minY + 10 + sin(CGFloat(i) / CGFloat(steps) * .pi * 4 + phase * .pi * 2) * 8
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
