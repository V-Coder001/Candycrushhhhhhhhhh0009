import Match3Core
import SpriteKit
import UIKit

/// Draws every piece in code, so the game needs no image assets.
/// Each colour also has its own shape, which keeps the board readable for colour-blind players.
@MainActor
final class CandyArt {
    static let shared = CandyArt()

    private var textures: [String: SKTexture] = [:]
    private var images: [String: UIImage] = [:]

    private init() {}

    func texture(for kind: PieceKind, size: CGFloat) -> SKTexture {
        let key = "\(kind)|\(Int(size.rounded()))"
        if let texture = textures[key] { return texture }
        let texture = SKTexture(image: image(for: kind, size: size))
        textures[key] = texture
        return texture
    }

    func image(for kind: PieceKind, size: CGFloat) -> UIImage {
        let key = "\(kind)|\(Int(size.rounded()))"
        if let image = images[key] { return image }
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let image = UIGraphicsImageRenderer(size: rect.size).image { context in
            let cg = context.cgContext
            switch kind {
            case let .candy(color, special): drawCandy(color, special, in: rect, cg)
            case .colorBomb: drawColorBomb(in: rect, cg)
            case .ingredient(.cherry): drawCherry(in: rect, cg)
            case .ingredient(.hazelnut): drawHazelnut(in: rect, cg)
            case .chocolate: drawChocolate(in: rect, cg)
            case let .blocker(hits): drawBlocker(hits: hits, in: rect, cg)
            }
        }
        images[key] = image
        return image
    }

    private(set) lazy var sprinkleTexture: SKTexture = {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 14, height: 5)).image { _ in
            UIColor.white.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 14, height: 5), cornerRadius: 2.5).fill()
        }
        return SKTexture(image: image)
    }()

    /// Soft light rays, used behind freshly made specials.
    private(set) lazy var raysTexture: SKTexture = {
        let size = CGSize(width: 128, height: 128)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let center = CGPoint(x: 64, y: 64)
            cg.saveGState()
            let rays = UIBezierPath()
            for i in 0..<12 {
                let a = CGFloat(i) / 12 * .pi * 2
                let w: CGFloat = .pi / 22
                rays.move(to: center)
                rays.addLine(to: CGPoint(x: center.x + cos(a - w) * 64, y: center.y + sin(a - w) * 64))
                rays.addLine(to: CGPoint(x: center.x + cos(a + w) * 64, y: center.y + sin(a + w) * 64))
                rays.close()
            }
            rays.addClip()
            let colors = [UIColor(hex: 0xFFF6C8).cgColor, UIColor(hex: 0xFFE27A, alpha: 0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: 64,
                                  options: [])
            cg.restoreGState()
        }
        return SKTexture(image: image)
    }()

    private(set) lazy var sparkTexture: SKTexture = {
        let size = CGSize(width: 24, height: 24)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            context.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 12, y: 12), startRadius: 0,
                                                 endCenter: CGPoint(x: 12, y: 12), endRadius: 12, options: [])
        }
        return SKTexture(image: image)
    }()

    func fishTexture(size: CGFloat) -> SKTexture {
        let key = "fish|\(Int(size))"
        if let texture = textures[key] { return texture }
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { context in
            drawFish(in: CGRect(x: 0, y: 0, width: size, height: size), color: .white, eye: Theme.accentUI,
                     context.cgContext)
        }
        let texture = SKTexture(image: image)
        textures[key] = texture
        return texture
    }

    func lockTexture(size: CGFloat) -> SKTexture {
        let key = "lock|\(Int(size))"
        if let texture = textures[key] { return texture }
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            let bar = UIColor(hex: 0x8E877E, alpha: 0.9)
            let path = UIBezierPath()
            let inset = size * 0.1
            for f in [0.33, 0.67] as [CGFloat] {
                path.move(to: CGPoint(x: inset, y: size * f))
                path.addLine(to: CGPoint(x: size - inset, y: size * f))
                path.move(to: CGPoint(x: size * f, y: inset))
                path.addLine(to: CGPoint(x: size * f, y: size - inset))
            }
            path.lineWidth = size * 0.075
            path.lineCapStyle = .round
            UIColor.white.withAlphaComponent(0.5).setStroke()
            let shadow = path.copy() as! UIBezierPath
            shadow.lineWidth = path.lineWidth + 2
            shadow.stroke()
            bar.setStroke()
            path.stroke()
        }
        let texture = SKTexture(image: image)
        textures[key] = texture
        return texture
    }

    // MARK: Shapes

    static func shapePath(_ color: CandyColor, in r: CGRect) -> UIBezierPath {
        let c = CGPoint(x: r.midX, y: r.midY)
        let w = r.width
        let h = r.height
        switch color {
        case .red:
            // Jelly bean, tilted.
            let bean = UIBezierPath(roundedRect: CGRect(x: -w * 0.5, y: -h * 0.3, width: w, height: h * 0.6),
                                    cornerRadius: h * 0.3)
            bean.apply(CGAffineTransform(rotationAngle: -.pi / 5))
            bean.apply(CGAffineTransform(translationX: c.x, y: c.y))
            return bean
        case .orange:
            // Round lozenge.
            return UIBezierPath(ovalIn: r.insetBy(dx: w * 0.04, dy: w * 0.04))
        case .yellow:
            // Drop.
            let center = CGPoint(x: c.x, y: r.minY + h * 0.62)
            let radius = w * 0.36
            let top = CGPoint(x: c.x, y: r.minY)
            let path = UIBezierPath()
            path.move(to: top)
            path.addCurve(to: CGPoint(x: center.x + radius, y: center.y),
                          controlPoint1: CGPoint(x: c.x + w * 0.1, y: r.minY + h * 0.18),
                          controlPoint2: CGPoint(x: center.x + radius, y: center.y - h * 0.22))
            path.addArc(withCenter: center, radius: radius, startAngle: 0, endAngle: .pi, clockwise: true)
            path.addCurve(to: top,
                          controlPoint1: CGPoint(x: center.x - radius, y: center.y - h * 0.22),
                          controlPoint2: CGPoint(x: c.x - w * 0.1, y: r.minY + h * 0.18))
            path.close()
            return path
        case .green:
            // Soft square chiclet.
            return UIBezierPath(roundedRect: r.insetBy(dx: w * 0.07, dy: h * 0.07), cornerRadius: w * 0.26)
        case .blue:
            // Gem.
            let points = [CGPoint(x: c.x, y: r.minY), CGPoint(x: r.maxX, y: c.y),
                          CGPoint(x: c.x, y: r.maxY), CGPoint(x: r.minX, y: c.y)]
            return roundedPolygon(points, radius: w * 0.1)
        case .purple:
            // Scalloped cluster.
            let points = (0..<12).map { i -> CGPoint in
                let angle = CGFloat(i) * .pi / 6 - .pi / 2
                let radius = i.isMultiple(of: 2) ? w * 0.52 : w * 0.4
                return CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
            }
            return roundedPolygon(points, radius: w * 0.12)
        }
    }

    static func roundedPolygon(_ points: [CGPoint], radius: CGFloat) -> UIBezierPath {
        let path = CGMutablePath()
        let n = points.count
        let last = points[n - 1]
        path.move(to: CGPoint(x: (last.x + points[0].x) / 2, y: (last.y + points[0].y) / 2))
        for i in 0..<n {
            path.addArc(tangent1End: points[i], tangent2End: points[(i + 1) % n], radius: radius)
        }
        path.closeSubpath()
        return UIBezierPath(cgPath: path)
    }

    // MARK: Pieces

    /// Saturated, shiny candy fill: drop shadow, radial body, dark rim and a bright highlight.
    private func fillGlossy(_ path: UIBezierPath, base: UIColor, in r: CGRect, _ cg: CGContext) {
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: r.height * 0.05), blur: r.height * 0.06,
                     color: base.darker(0.6).withAlphaComponent(0.45).cgColor)
        base.setFill()
        path.fill()
        cg.restoreGState()

        cg.saveGState()
        path.addClip()
        let colors = [base.lighter(0.5).cgColor, base.cgColor, base.darker(0.38).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.45, 1]) {
            let center = CGPoint(x: r.minX + r.width * 0.4, y: r.minY + r.height * 0.32)
            cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                  endCenter: CGPoint(x: r.midX, y: r.midY), endRadius: r.width * 0.62,
                                  options: [.drawsAfterEndLocation])
        }
        path.lineWidth = r.width * 0.05
        base.darker(0.3).withAlphaComponent(0.6).setStroke()
        path.stroke()

        let highlight = UIBezierPath(ovalIn: CGRect(x: -r.width * 0.2, y: -r.height * 0.1,
                                                    width: r.width * 0.4, height: r.height * 0.2))
        highlight.apply(CGAffineTransform(rotationAngle: -.pi / 7))
        highlight.apply(CGAffineTransform(translationX: r.minX + r.width * 0.38, y: r.minY + r.height * 0.26))
        cg.saveGState()
        highlight.addClip()
        let shine = [UIColor.white.withAlphaComponent(0.95).cgColor, UIColor.white.withAlphaComponent(0.15).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: shine, locations: [0, 1]) {
            cg.drawLinearGradient(gradient, start: CGPoint(x: r.midX, y: r.minY + r.height * 0.14),
                                  end: CGPoint(x: r.midX, y: r.minY + r.height * 0.38), options: [])
        }
        cg.restoreGState()
        UIColor.white.withAlphaComponent(0.55).setFill()
        UIBezierPath(ovalIn: CGRect(x: r.minX + r.width * 0.66, y: r.minY + r.height * 0.64,
                                    width: r.width * 0.08, height: r.width * 0.08)).fill()
        cg.restoreGState()
    }

    private func drawCandy(_ color: CandyColor, _ special: Special, in rect: CGRect, _ cg: CGContext) {
        let base = Theme.candy(color)
        let isWrapped = special == .wrapped || special == .wrappedArmed
        let r = rect.insetBy(dx: rect.width * (isWrapped ? 0.18 : 0.05), dy: rect.height * (isWrapped ? 0.18 : 0.05))
        let path = Self.shapePath(color, in: r)

        if isWrapped {
            // Wrapper ends to the left and right.
            let wrapper = base.darker(0.08)
            wrapper.setFill()
            for side in [-1.0, 1.0] as [CGFloat] {
                let x = side < 0 ? r.minX + r.width * 0.05 : r.maxX - r.width * 0.05
                let tip = side < 0 ? rect.minX + rect.width * 0.04 : rect.maxX - rect.width * 0.04
                let bow = UIBezierPath()
                bow.move(to: CGPoint(x: x, y: rect.midY))
                bow.addLine(to: CGPoint(x: tip, y: rect.midY - rect.height * 0.17))
                bow.addQuadCurve(to: CGPoint(x: tip, y: rect.midY + rect.height * 0.17),
                                 controlPoint: CGPoint(x: tip + side * rect.width * 0.04, y: rect.midY))
                bow.close()
                bow.fill()
            }
            if special == .wrappedArmed {
                cg.saveGState()
                cg.setShadow(offset: .zero, blur: rect.width * 0.18, color: UIColor.white.cgColor)
                base.lighter(0.3).setFill()
                path.fill()
                cg.restoreGState()
            }
        }

        fillGlossy(path, base: base, in: r, cg)

        switch special {
        case .stripedHorizontal, .stripedVertical:
            cg.saveGState()
            path.addClip()
            UIColor.white.withAlphaComponent(0.85).setFill()
            for i in 0..<3 {
                let f = 0.28 + CGFloat(i) * 0.22
                let bar: CGRect
                if special == .stripedHorizontal {
                    bar = CGRect(x: r.minX, y: r.minY + r.height * f - r.height * 0.05, width: r.width, height: r.height * 0.1)
                } else {
                    bar = CGRect(x: r.minX + r.width * f - r.width * 0.05, y: r.minY, width: r.width * 0.1, height: r.height)
                }
                UIBezierPath(roundedRect: bar, cornerRadius: r.width * 0.05).fill()
            }
            cg.restoreGState()
        case .wrapped, .wrappedArmed:
            path.lineWidth = rect.width * 0.05
            UIColor.white.withAlphaComponent(0.9).setStroke()
            path.stroke()
        case .fish:
            let fishRect = r.insetBy(dx: r.width * 0.2, dy: r.height * 0.2)
            drawFish(in: fishRect, color: UIColor.white.withAlphaComponent(0.92), eye: base.darker(0.3), cg)
        case .none:
            break
        }
    }

    private func drawFish(in r: CGRect, color: UIColor, eye: UIColor, _ cg: CGContext) {
        color.setFill()
        let body = UIBezierPath(ovalIn: CGRect(x: r.minX + r.width * 0.28, y: r.midY - r.height * 0.22,
                                               width: r.width * 0.66, height: r.height * 0.44))
        body.fill()
        let tail = UIBezierPath()
        tail.move(to: CGPoint(x: r.minX + r.width * 0.34, y: r.midY))
        tail.addLine(to: CGPoint(x: r.minX + r.width * 0.04, y: r.midY - r.height * 0.2))
        tail.addLine(to: CGPoint(x: r.minX + r.width * 0.04, y: r.midY + r.height * 0.2))
        tail.close()
        tail.fill()
        eye.setFill()
        let eyeSize = r.width * 0.09
        UIBezierPath(ovalIn: CGRect(x: r.minX + r.width * 0.72, y: r.midY - r.height * 0.1,
                                    width: eyeSize, height: eyeSize)).fill()
    }

    private func drawColorBomb(in rect: CGRect, _ cg: CGContext) {
        let r = rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1)
        let path = UIBezierPath(ovalIn: r)
        fillGlossy(path, base: UIColor(hex: 0x5C3B2E), in: r, cg)
        cg.saveGState()
        path.addClip()
        var seed: UInt32 = 7
        func next() -> CGFloat {
            seed = seed &* 1_103_515_245 &+ 12_345
            return CGFloat((seed >> 16) & 0x7FFF) / CGFloat(0x7FFF)
        }
        let colors = CandyColor.allCases.map(Theme.candy) + [.white]
        for i in 0..<18 {
            let angle = next() * .pi * 2
            let distance = sqrt(next()) * r.width * 0.42
            let center = CGPoint(x: r.midX + cos(angle) * distance, y: r.midY + sin(angle) * distance)
            let sprinkle = UIBezierPath(roundedRect: CGRect(x: -r.width * 0.07, y: -r.width * 0.025,
                                                            width: r.width * 0.14, height: r.width * 0.05),
                                        cornerRadius: r.width * 0.025)
            sprinkle.apply(CGAffineTransform(rotationAngle: next() * .pi))
            sprinkle.apply(CGAffineTransform(translationX: center.x, y: center.y))
            colors[i % colors.count].setFill()
            sprinkle.fill()
        }
        cg.restoreGState()
    }

    private func drawCherry(in rect: CGRect, _ cg: CGContext) {
        let w = rect.width
        let stem = UIBezierPath()
        stem.move(to: CGPoint(x: rect.minX + w * 0.33, y: rect.minY + w * 0.62))
        stem.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.56, y: rect.minY + w * 0.14),
                          controlPoint: CGPoint(x: rect.minX + w * 0.38, y: rect.minY + w * 0.3))
        stem.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.68, y: rect.minY + w * 0.6),
                          controlPoint: CGPoint(x: rect.minX + w * 0.64, y: rect.minY + w * 0.3))
        stem.lineWidth = w * 0.045
        stem.lineCapStyle = .round
        UIColor(hex: 0x6E8B4E).setStroke()
        stem.stroke()
        let leaf = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: w * 0.24, height: w * 0.11))
        leaf.apply(CGAffineTransform(rotationAngle: -0.5))
        leaf.apply(CGAffineTransform(translationX: rect.minX + w * 0.56, y: rect.minY + w * 0.2))
        UIColor(hex: 0x86BA84).setFill()
        leaf.fill()
        for x in [0.33, 0.68] as [CGFloat] {
            let cherry = CGRect(x: rect.minX + w * x - w * 0.19, y: rect.minY + w * 0.5, width: w * 0.38, height: w * 0.38)
            fillGlossy(UIBezierPath(ovalIn: cherry), base: UIColor(hex: 0xD2504F), in: cherry, cg)
        }
    }

    private func drawHazelnut(in rect: CGRect, _ cg: CGContext) {
        let w = rect.width
        let body = CGRect(x: rect.minX + w * 0.18, y: rect.minY + w * 0.26, width: w * 0.64, height: w * 0.62)
        fillGlossy(UIBezierPath(ovalIn: body), base: UIColor(hex: 0xB07A4A), in: body, cg)
        let cap = UIBezierPath(roundedRect: CGRect(x: rect.minX + w * 0.16, y: rect.minY + w * 0.2,
                                                   width: w * 0.68, height: w * 0.26), cornerRadius: w * 0.12)
        fillGlossy(cap, base: UIColor(hex: 0x7C5431), in: cap.bounds, cg)
        let tip = UIBezierPath(roundedRect: CGRect(x: rect.midX - w * 0.035, y: rect.minY + w * 0.1,
                                                   width: w * 0.07, height: w * 0.14), cornerRadius: w * 0.035)
        UIColor(hex: 0x6B4A2C).setFill()
        tip.fill()
    }

    private func drawChocolate(in rect: CGRect, _ cg: CGContext) {
        let r = rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06)
        let path = UIBezierPath(roundedRect: r, cornerRadius: r.width * 0.16)
        fillGlossy(path, base: UIColor(hex: 0x6E4331), in: r, cg)
        let inner = r.insetBy(dx: r.width * 0.12, dy: r.height * 0.12)
        let half = inner.width / 2
        for (dx, dy) in [(0, 0), (1, 0), (0, 1), (1, 1)] as [(CGFloat, CGFloat)] {
            let square = CGRect(x: inner.minX + dx * half + 2, y: inner.minY + dy * half + 2,
                                width: half - 4, height: half - 4)
            UIColor(hex: 0x8A5842).setFill()
            UIBezierPath(roundedRect: square, cornerRadius: half * 0.18).fill()
            UIColor.white.withAlphaComponent(0.12).setFill()
            UIBezierPath(roundedRect: CGRect(x: square.minX, y: square.minY, width: square.width,
                                             height: square.height * 0.3), cornerRadius: half * 0.12).fill()
        }
    }

    private func drawBlocker(hits: Int, in rect: CGRect, _ cg: CGContext) {
        let r = rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06)
        let path = UIBezierPath(roundedRect: r, cornerRadius: r.width * 0.14)
        let base = UIColor(hex: hits >= 3 ? 0xE2D6C3 : (hits == 2 ? 0xEDE3D4 : 0xF6F0E6))
        fillGlossy(path, base: base, in: r, cg)
        UIColor(hex: 0xC9BBA5).setStroke()
        path.lineWidth = r.width * 0.03
        path.stroke()
        // One inner ring per remaining hit.
        for i in 0..<max(0, hits - 1) {
            let inset = r.width * (0.16 + CGFloat(i) * 0.12)
            let ring = UIBezierPath(roundedRect: r.insetBy(dx: inset, dy: inset), cornerRadius: r.width * 0.1)
            ring.lineWidth = r.width * 0.035
            UIColor(hex: 0xBFAF97).setStroke()
            ring.stroke()
        }
        UIColor.white.withAlphaComponent(0.8).setFill()
        for (x, y) in [(0.25, 0.22), (0.72, 0.3), (0.35, 0.75)] as [(CGFloat, CGFloat)] {
            UIBezierPath(ovalIn: CGRect(x: r.minX + r.width * x, y: r.minY + r.height * y,
                                        width: r.width * 0.05, height: r.width * 0.05)).fill()
        }
    }
}
