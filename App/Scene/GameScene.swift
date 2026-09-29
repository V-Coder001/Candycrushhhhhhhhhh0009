import Match3Core
import SpriteKit
import UIKit

@MainActor
protocol GameSceneDelegate: AnyObject {
    /// Runs the move in the game model. Nil if moves are not allowed right now.
    func scene(_ scene: GameScene, requestSwap from: Position, to: Position) -> MoveResult?
    func sceneDidApply(_ step: CascadeStep)
    func sceneDidShow(_ word: ComboWord)
    func sceneDidFinish(_ move: MoveResult)
    func sceneHint() -> (Position, Position)?
}

/// Renders the board and plays back `MoveResult`s as animations. All rules live in `Game`.
final class GameScene: SKScene {
    weak var gameDelegate: GameSceneDelegate?

    var isDark = false {
        didSet { if oldValue != isDark { rebuild() } }
    }

    private(set) var board: Board
    private(set) var isBusy = false

    private let boardNode = SKNode()
    private let tileLayer = SKNode()
    private let crop = SKCropNode()
    private let pieceLayer = SKNode()
    private let overlayLayer = SKNode()
    private let effectLayer = SKNode()

    private var sprites: [Int: SKSpriteNode] = [:]
    private var spriteKinds: [Int: PieceKind] = [:]
    private var jellyNodes: [Position: SKShapeNode] = [:]
    private var lockNodes: [Position: SKSpriteNode] = [:]
    private var selectionNode: SKShapeNode?
    private var selected: Position?
    private var touchStart: (position: Position, point: CGPoint)?
    private var hinted: [SKSpriteNode] = []
    private var hintTask: Task<Void, Never>?
    private var tile: CGFloat = 40
    private let art = CandyArt.shared
    private let sound = SoundManager.shared

    private enum Timing {
        static let swap: TimeInterval = 0.16
        static let pop: TimeInterval = 0.2
        static let fallPerRow: TimeInterval = 0.055
        static let fallBase: TimeInterval = 0.1
        static let hintDelay: TimeInterval = 6
    }

    init(board: Board) {
        self.board = board
        super.init(size: CGSize(width: 390, height: 390))
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .clear

        addChild(boardNode)
        tileLayer.zPosition = 0
        crop.zPosition = 10
        overlayLayer.zPosition = 20
        effectLayer.zPosition = 30
        boardNode.addChild(tileLayer)
        boardNode.addChild(crop)
        crop.addChild(pieceLayer)
        boardNode.addChild(overlayLayer)
        boardNode.addChild(effectLayer)
        rebuild()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size != oldSize else { return }
        rebuild()
    }

    func reset(board: Board) {
        hideHint()
        self.board = board
        isBusy = false
        rebuild()
    }

    // MARK: Layout

    private func point(row: Int, col: Int) -> CGPoint {
        CGPoint(x: (CGFloat(col) - CGFloat(board.columns - 1) / 2) * tile,
                y: (CGFloat(board.rows - 1) / 2 - CGFloat(row)) * tile)
    }

    private func point(for p: Position) -> CGPoint { point(row: p.row, col: p.col) }

    private func position(at point: CGPoint) -> Position? {
        let col = Int(floor(point.x / tile + CGFloat(board.columns) / 2))
        let row = Int(floor(CGFloat(board.rows) / 2 - point.y / tile))
        let p = Position(row, col)
        return board.isPlayable(p) ? p : nil
    }

    private var pieceSize: CGFloat { tile * 0.9 }

    private func rebuild() {
        guard board.columns > 0, size.width > 1, size.height > 1 else { return }
        tile = max(10, floor(min(size.width / CGFloat(board.columns), size.height / CGFloat(board.rows))))
        boardNode.removeAllActions()
        boardNode.position = .zero
        [tileLayer, pieceLayer, overlayLayer, effectLayer].forEach { $0.removeAllChildren() }
        sprites = [:]
        spriteKinds = [:]
        jellyNodes = [:]
        lockNodes = [:]
        selectionNode = nil
        selected = nil
        hinted = []

        // Only the board area shows pieces, so refills slide in from behind the top edge.
        let mask = SKNode()
        for p in board.positions {
            let tileNode = SKShapeNode(rectOf: CGSize(width: tile - 2, height: tile - 2), cornerRadius: tile * 0.2)
            let alt = (p.row + p.col).isMultiple(of: 2)
            tileNode.fillColor = (alt ? Theme.tileUI : Theme.tileAltUI).resolved(dark: isDark)
            tileNode.strokeColor = .clear
            tileNode.position = point(for: p)
            tileLayer.addChild(tileNode)

            let maskTile = SKSpriteNode(color: .white, size: CGSize(width: tile, height: tile))
            maskTile.position = point(for: p)
            mask.addChild(maskTile)
            updateCellDecor(at: p, cell: board.cell(p))
        }
        crop.maskNode = mask

        for (p, piece) in board.allPieces {
            addSprite(for: piece, at: p)
        }
    }

    private func updateCellDecor(at p: Position, cell: Cell) {
        if cell.jelly > 0 {
            let node = jellyNodes[p] ?? {
                let node = SKShapeNode(rectOf: CGSize(width: tile - 4, height: tile - 4), cornerRadius: tile * 0.2)
                node.position = point(for: p)
                node.zPosition = 1
                tileLayer.addChild(node)
                jellyNodes[p] = node
                return node
            }()
            node.fillColor = Theme.jellyUI.withAlphaComponent(cell.jelly >= 2 ? 0.75 : 0.42)
            node.strokeColor = Theme.jellyUI.darker(0.1).withAlphaComponent(0.6)
            node.lineWidth = 1.5
        } else if let node = jellyNodes.removeValue(forKey: p) {
            node.run(.sequence([.group([.fadeOut(withDuration: 0.25), .scale(to: 1.15, duration: 0.25)]),
                                .removeFromParent()]))
        }

        if cell.locked, lockNodes[p] == nil {
            let lock = SKSpriteNode(texture: art.lockTexture(size: tile))
            lock.size = CGSize(width: tile, height: tile)
            lock.position = point(for: p)
            overlayLayer.addChild(lock)
            lockNodes[p] = lock
        } else if !cell.locked, let lock = lockNodes.removeValue(forKey: p) {
            lock.run(.sequence([.group([.fadeOut(withDuration: 0.2), .scale(to: 1.3, duration: 0.2)]),
                                .removeFromParent()]))
        }
    }

    @discardableResult
    private func addSprite(for piece: Piece, at p: Position) -> SKSpriteNode {
        let node = SKSpriteNode(texture: art.texture(for: piece.kind, size: pieceSize))
        node.size = CGSize(width: pieceSize, height: pieceSize)
        node.position = point(for: p)
        pieceLayer.addChild(node)
        sprites[piece.id] = node
        spriteKinds[piece.id] = piece.kind
        if piece.kind.special == .wrappedArmed { armedPulse(node) }
        return node
    }

    private func setKind(_ kind: PieceKind, for id: Int) {
        guard let node = sprites[id], spriteKinds[id] != kind else { return }
        node.texture = art.texture(for: kind, size: pieceSize)
        spriteKinds[id] = kind
        if kind.special == .wrappedArmed { armedPulse(node) }
    }

    private func armedPulse(_ node: SKSpriteNode) {
        let pulse = SKAction.sequence([.scale(to: 1.08, duration: 0.3), .scale(to: 0.96, duration: 0.3)])
        pulse.timingMode = .easeInEaseOut
        node.run(.repeatForever(pulse), withKey: "pulse")
    }

    /// Brings every node in line with a board snapshot (after animations, or as a safety net).
    private func reconcile(with newBoard: Board) {
        board = newBoard
        var alive = Set<Int>()
        for (p, piece) in newBoard.allPieces {
            alive.insert(piece.id)
            if let node = sprites[piece.id] {
                setKind(piece.kind, for: piece.id)
                let target = point(for: p)
                if hypot(node.position.x - target.x, node.position.y - target.y) > 0.5 {
                    node.removeAction(forKey: "move")
                    node.position = target
                }
                node.alpha = 1
            } else {
                addSprite(for: piece, at: p)
            }
        }
        for (id, node) in sprites where !alive.contains(id) {
            node.removeFromParent()
            sprites[id] = nil
            spriteKinds[id] = nil
        }
        for p in newBoard.positions {
            updateCellDecor(at: p, cell: newBoard.cell(p))
        }
    }

    // MARK: Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isBusy, let touch = touches.first else { return }
        hideHint()
        let location = touch.location(in: boardNode)
        guard let p = position(at: location) else {
            clearSelection()
            return
        }
        if let current = selected, current.isAdjacent(to: p) {
            clearSelection()
            performSwap(current, p)
            return
        }
        touchStart = (p, location)
        select(p)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isBusy, let start = touchStart, let touch = touches.first else { return }
        let location = touch.location(in: boardNode)
        let dx = location.x - start.point.x
        let dy = location.y - start.point.y
        guard max(abs(dx), abs(dy)) > tile * 0.35 else { return }
        let target = abs(dx) > abs(dy)
            ? Position(start.position.row, start.position.col + (dx > 0 ? 1 : -1))
            : Position(start.position.row + (dy > 0 ? -1 : 1), start.position.col)
        touchStart = nil
        clearSelection()
        performSwap(start.position, target)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
    }

    private func select(_ p: Position) {
        guard board.isSwappable(p) else {
            clearSelection()
            return
        }
        selected = p
        selectionNode?.removeFromParent()
        let node = SKShapeNode(rectOf: CGSize(width: tile - 2, height: tile - 2), cornerRadius: tile * 0.22)
        node.strokeColor = Theme.accentUI
        node.lineWidth = 2.5
        node.fillColor = Theme.accentUI.withAlphaComponent(0.1)
        node.position = point(for: p)
        node.zPosition = -1
        overlayLayer.addChild(node)
        node.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
        selectionNode = node
        Haptics.tap()
    }

    private func clearSelection() {
        selected = nil
        selectionNode?.removeFromParent()
        selectionNode = nil
    }

    func performSwap(_ a: Position, _ b: Position) {
        guard board.isPlayable(b), let result = gameDelegate?.scene(self, requestSwap: a, to: b) else { return }
        isBusy = true
        Task { @MainActor in
            if result.isValid {
                await play(result)
            } else {
                await playRejected(a, b)
            }
            isBusy = false
            scheduleHint()
        }
    }

    // MARK: Playback

    private func play(_ result: MoveResult) async {
        sound.play(.swap)
        await animateSwap(result.from, result.to)

        for step in result.steps {
            await animate(step)
            gameDelegate?.sceneDidApply(step)
        }

        if let spread = result.chocolateSpread {
            await animateSpread(spread)
        }
        if let word = result.comboWord {
            gameDelegate?.sceneDidShow(word)
            sound.say(word)
        }
        if let shuffled = result.shuffledBoard {
            await wait(0.3)
            await animateShuffle(to: shuffled)
        }
        reconcile(with: result.board)
        gameDelegate?.sceneDidFinish(result)
    }

    private func playRejected(_ a: Position, _ b: Position) async {
        guard let pa = board[a], let pb = board[b], let na = sprites[pa.id], let nb = sprites[pb.id],
              board.isSwappable(a), board.isSwappable(b) else {
            if let piece = board[a], let node = sprites[piece.id] { nudge(node) }
            Haptics.invalid()
            return
        }
        sound.play(.swap)
        let pointA = point(for: a)
        let pointB = point(for: b)
        await group([
            (na, move(to: pointB, duration: Timing.swap)),
            (nb, move(to: pointA, duration: Timing.swap)),
        ])
        sound.play(.invalid)
        Haptics.invalid()
        await group([
            (na, move(to: pointA, duration: Timing.swap)),
            (nb, move(to: pointB, duration: Timing.swap)),
        ])
    }

    private func animateSwap(_ from: Position, _ to: Position) async {
        guard let pa = board[from], let pb = board[to], let na = sprites[pa.id], let nb = sprites[pb.id] else { return }
        na.zPosition = 2
        await group([
            (na, move(to: point(for: to), duration: Timing.swap)),
            (nb, move(to: point(for: from), duration: Timing.swap)),
        ])
        na.zPosition = 0
        var swapped = board
        swapped[to] = pa
        swapped[from] = pb
        board = swapped
    }

    private func animate(_ step: CascadeStep) async {
        // Power-ups: transform, then fire.
        for t in step.transformed {
            setKind(t.piece.kind, for: t.piece.id)
            sprites[t.piece.id]?.fire(.sequence([.scale(to: 1.2, duration: 0.1), .scale(to: 1, duration: 0.1)]))
        }
        if !step.transformed.isEmpty { await wait(0.25) }

        for activation in step.activations {
            showActivation(activation)
        }
        if !step.activations.isEmpty {
            sound.play(.special, pitch: 1 + Double(step.index - 1) * 0.08)
            await wait(0.12)
        }
        if step.isBigExplosion {
            shake(intensity: step.activations.contains { $0.kind == .wholeBoard } ? 1.6 : 1)
            sound.play(.bomb)
            Haptics.explosion()
        }

        // Pop.
        for cleared in step.cleared {
            guard let node = sprites.removeValue(forKey: cleared.piece.id) else { continue }
            spriteKinds[cleared.piece.id] = nil
            node.removeAllActions()
            burst(at: node.position, color: Theme.tint(for: cleared.piece.kind),
                  amount: cleared.piece.kind.isPlainCandy ? 9 : 16)
            node.fire(.sequence([
                .scale(to: 1.15, duration: 0.05),
                .group([.scale(to: 0.1, duration: Timing.pop), .fadeOut(withDuration: Timing.pop)]),
                .removeFromParent(),
            ]))
        }
        if !step.cleared.isEmpty {
            sound.play(.pop, pitch: min(2, 1 + Double(step.index - 1) * 0.12))
            Haptics.pop()
        }
        for damaged in step.damaged {
            setKind(damaged.piece.kind, for: damaged.piece.id)
            if let node = sprites[damaged.piece.id] { nudge(node) }
        }
        if !step.damaged.isEmpty || !step.locksBroken.isEmpty || step.cleared.contains(where: { $0.piece.kind.isObstacle }) {
            sound.play(.crunch)
        }
        for p in step.locksBroken + step.jellyHit {
            updateCellDecor(at: p, cell: step.board.cell(p))
        }
        await wait(Timing.pop)

        // New specials appear where the match happened.
        for placed in step.created + step.rearmed {
            let node = addSprite(for: placed.piece, at: placed.position)
            node.setScale(0.2)
            let grow = SKAction.scale(to: 1, duration: 0.22)
            grow.timingMode = .easeOut
            node.fire(grow)
            if placed.piece.kind.special != .wrappedArmed {
                burst(at: node.position, color: .white, amount: 8)
            }
        }
        if !step.created.isEmpty {
            sound.play(.special, pitch: 1.3)
            Haptics.special()
            await wait(0.18)
        }

        // Gravity and refill.
        var longest: TimeInterval = 0
        for fall in step.falls {
            guard let node = sprites[fall.pieceID] else { continue }
            let rows = CGFloat(abs(fall.to.row - fall.from.row) + abs(fall.to.col - fall.from.col))
            let duration = Timing.fallBase + Timing.fallPerRow * TimeInterval(rows)
            node.run(fallAction(to: point(for: fall.to), duration: duration), withKey: "move")
            longest = max(longest, duration)
        }
        for spawn in step.spawns {
            let node = addSprite(for: spawn.piece, at: spawn.position)
            node.position = point(row: spawn.startRow, col: spawn.startColumn)
            let rows = CGFloat(spawn.position.row - spawn.startRow)
            let duration = Timing.fallBase + Timing.fallPerRow * TimeInterval(rows)
            node.run(fallAction(to: point(for: spawn.position), duration: duration), withKey: "move")
            longest = max(longest, duration)
        }
        await wait(longest + 0.12)

        // Ingredients leave through the bottom.
        for collected in step.collected {
            guard let node = sprites.removeValue(forKey: collected.piece.id) else { continue }
            spriteKinds[collected.piece.id] = nil
            burst(at: node.position, color: Theme.starUI, amount: 14)
            node.fire(.sequence([
                .group([.moveBy(x: 0, y: -tile * 0.9, duration: 0.3), .fadeOut(withDuration: 0.3)]),
                .removeFromParent(),
            ]))
        }
        if !step.collected.isEmpty {
            sound.play(.collect)
            Haptics.success()
            await wait(0.3)
        }

        reconcile(with: step.board)
    }

    private func animateSpread(_ spread: ChocolateSpread) async {
        if let old = sprites.removeValue(forKey: spread.replaced.id) {
            spriteKinds[spread.replaced.id] = nil
            old.fire(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        }
        let node = addSprite(for: spread.chocolate, at: spread.to)
        node.position = point(for: spread.from)
        node.setScale(0.4)
        node.fire(.group([.move(to: point(for: spread.to), duration: 0.3), .scale(to: 1, duration: 0.3)]))
        sound.play(.crunch, pitch: 0.8)
        await wait(0.35)
    }

    private func animateShuffle(to shuffled: Board) async {
        for (p, piece) in shuffled.allPieces {
            guard let node = sprites[piece.id] else { continue }
            let move = SKAction.move(to: point(for: p), duration: 0.45)
            move.timingMode = .easeInEaseOut
            node.run(move, withKey: "move")
        }
        await wait(0.5)
    }

    // MARK: Effects

    private func showActivation(_ activation: Activation) {
        let origin = point(for: activation.origin)
        let boardWidth = tile * CGFloat(board.columns)
        let boardHeight = tile * CGFloat(board.rows)

        func beam(horizontal: Bool, through p: CGPoint, thickness: CGFloat) {
            let size = horizontal ? CGSize(width: boardWidth, height: thickness) : CGSize(width: thickness, height: boardHeight)
            let node = SKShapeNode(rectOf: size, cornerRadius: thickness / 2)
            node.fillColor = UIColor.white.withAlphaComponent(0.85)
            node.strokeColor = .clear
            node.glowWidth = thickness * 0.3
            node.position = horizontal ? CGPoint(x: 0, y: p.y) : CGPoint(x: p.x, y: 0)
            if horizontal { node.xScale = 0.05 } else { node.yScale = 0.05 }
            effectLayer.addChild(node)
            let grow = horizontal ? SKAction.scaleX(to: 1, duration: 0.14) : SKAction.scaleY(to: 1, duration: 0.14)
            grow.timingMode = .easeOut
            node.run(.sequence([grow, .fadeOut(withDuration: 0.25), .removeFromParent()]))
        }

        switch activation.kind {
        case .lineHorizontal:
            beam(horizontal: true, through: origin, thickness: tile * 0.34)
        case .lineVertical:
            beam(horizontal: false, through: origin, thickness: tile * 0.34)
        case let .cross(width):
            for d in -(width / 2)...(width / 2) {
                beam(horizontal: true, through: point(row: activation.origin.row + d, col: 0), thickness: tile * 0.4)
                beam(horizontal: false, through: point(row: 0, col: activation.origin.col + d), thickness: tile * 0.4)
            }
        case let .area(radius):
            let ring = SKShapeNode(circleOfRadius: tile * 0.5)
            ring.strokeColor = UIColor.white.withAlphaComponent(0.9)
            ring.lineWidth = 4
            ring.glowWidth = 3
            ring.fillColor = UIColor.white.withAlphaComponent(0.15)
            ring.position = origin
            effectLayer.addChild(ring)
            let scale = SKAction.scale(to: CGFloat(radius * 2 + 1) * 0.9, duration: 0.25)
            scale.timingMode = .easeOut
            ring.run(.sequence([.group([scale, .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
        case .colorBomb:
            for target in activation.affected {
                let path = CGMutablePath()
                path.move(to: origin)
                path.addLine(to: point(for: target))
                let line = SKShapeNode(path: path)
                line.strokeColor = UIColor.white.withAlphaComponent(0.8)
                line.lineWidth = 2
                line.glowWidth = 2
                line.alpha = 0
                effectLayer.addChild(line)
                line.run(.sequence([.fadeIn(withDuration: 0.08), .wait(forDuration: 0.1),
                                    .fadeOut(withDuration: 0.2), .removeFromParent()]))
                spark(at: point(for: target))
            }
        case let .fish(target):
            let fish = SKSpriteNode(texture: art.fishTexture(size: tile * 0.7))
            fish.size = CGSize(width: tile * 0.7, height: tile * 0.7)
            fish.position = origin
            let end = point(for: target)
            fish.zRotation = atan2(end.y - origin.y, end.x - origin.x)
            effectLayer.addChild(fish)
            let fly = SKAction.move(to: end, duration: 0.28)
            fly.timingMode = .easeInEaseOut
            fish.run(.sequence([fly, .fadeOut(withDuration: 0.1), .removeFromParent()]))
            Task { @MainActor [weak self] in
                await self?.wait(fly.duration)
                self?.spark(at: end)
            }
        case .wholeBoard:
            let flash = SKSpriteNode(color: .white, size: CGSize(width: boardWidth, height: boardHeight))
            flash.alpha = 0
            effectLayer.addChild(flash)
            flash.run(.sequence([.fadeAlpha(to: 0.85, duration: 0.08), .fadeOut(withDuration: 0.45), .removeFromParent()]))
        }
    }

    /// Sugar sprinkles flying out of a popped candy.
    private func burst(at position: CGPoint, color: UIColor, amount: Int) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = art.sprinkleTexture
        emitter.particleBirthRate = 600
        emitter.numParticlesToEmit = amount
        emitter.particleLifetime = 0.6
        emitter.particleLifetimeRange = 0.25
        emitter.particleSpeed = tile * 3
        emitter.particleSpeedRange = tile * 2
        emitter.emissionAngleRange = .pi * 2
        emitter.yAcceleration = -tile * 10
        emitter.particleAlphaSpeed = -1.5
        emitter.particleScale = tile / 70
        emitter.particleScaleRange = tile / 140
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = 5
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.position = position
        effectLayer.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1), .removeFromParent()]))
    }

    private func spark(at position: CGPoint) {
        let spark = SKSpriteNode(texture: art.sparkTexture)
        spark.size = CGSize(width: tile, height: tile)
        spark.position = position
        spark.blendMode = .add
        spark.setScale(0.3)
        effectLayer.addChild(spark)
        spark.run(.sequence([.group([.scale(to: 1.3, duration: 0.2), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
    }

    /// Gentle screen shake for big explosions.
    private func shake(intensity: CGFloat) {
        boardNode.removeAction(forKey: "shake")
        boardNode.position = .zero
        let amplitude = tile * 0.12 * intensity
        var actions: [SKAction] = []
        for i in 0..<6 {
            let falloff = 1 - CGFloat(i) / 6
            let offset = CGPoint(x: CGFloat.random(in: -1...1) * amplitude * falloff,
                                 y: CGFloat.random(in: -1...1) * amplitude * falloff)
            actions.append(.move(to: offset, duration: 0.035))
        }
        actions.append(.move(to: .zero, duration: 0.05))
        boardNode.run(.sequence(actions), withKey: "shake")
    }

    private func nudge(_ node: SKNode) {
        let d = tile * 0.06
        node.run(.sequence([.moveBy(x: -d, y: 0, duration: 0.04), .moveBy(x: 2 * d, y: 0, duration: 0.06),
                            .moveBy(x: -d, y: 0, duration: 0.04)]))
    }

    // MARK: Hint

    func scheduleHint() {
        hintTask?.cancel()
        hintTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Timing.hintDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.showHint()
        }
    }

    private func showHint() {
        guard !isBusy, let (a, b) = gameDelegate?.sceneHint() else { return }
        hinted = [a, b].compactMap { board[$0].flatMap { sprites[$0.id] } }
        let pulse = SKAction.sequence([.scale(to: 1.1, duration: 0.35), .scale(to: 1, duration: 0.35)])
        pulse.timingMode = .easeInEaseOut
        hinted.forEach { $0.run(.repeatForever(pulse), withKey: "hint") }
    }

    private func hideHint() {
        hintTask?.cancel()
        for node in hinted {
            node.removeAction(forKey: "hint")
            node.setScale(1)
        }
        hinted = []
    }

    // MARK: Action helpers

    private func move(to point: CGPoint, duration: TimeInterval) -> SKAction {
        let action = SKAction.move(to: point, duration: duration)
        action.timingMode = .easeInEaseOut
        return action
    }

    private func fallAction(to point: CGPoint, duration: TimeInterval) -> SKAction {
        let fall = SKAction.move(to: point, duration: duration)
        fall.timingMode = .easeIn
        let bounce = tile * 0.07
        let up = SKAction.moveBy(x: 0, y: bounce, duration: 0.06)
        up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -bounce, duration: 0.06)
        down.timingMode = .easeIn
        return .sequence([fall, up, down])
    }

    /// Runs actions on several nodes and waits for the longest one.
    private func group(_ items: [(SKNode, SKAction)]) async {
        for (node, action) in items { node.run(action, withKey: "move") }
        await wait(items.map(\.1.duration).max() ?? 0)
    }

    private func wait(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

private extension SKNode {
    /// Fire-and-forget `run`. Inside async functions plain `run(_:)` resolves to the awaiting overload.
    func fire(_ action: SKAction) {
        run(action, completion: {})
    }
}
