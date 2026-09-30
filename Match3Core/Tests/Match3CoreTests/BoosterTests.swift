import XCTest
@testable import Match3Core

final class BoosterTests: XCTestCase {
    // MARK: Hammer

    func testHammerSmashesCandyWithoutSpendingAMove() {
        let board = Board.parse([
            "R G B",
            "G B R",
            "B R G",
        ])
        let target = board[Position(1, 1)]!.id
        let game = Game(level: testLevel(), board: board)
        let result = game.useHammer(at: Position(1, 1))
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(game.movesLeft, 10)
        XCTAssertEqual(result.steps.first?.activations.first?.kind, .hammer)
        XCTAssertTrue(result.steps[0].cleared.contains { $0.piece.id == target })
        XCTAssertFalse(MatchFinder.hasAnyMatch(in: game.board))
        XCTAssertTrue(game.board.positions.allSatisfy { game.board[$0] != nil }, "\(game.board)")
        XCTAssertEqual(game.status, .playing)
    }

    func testHammerBreaksLockAndKeepsCandy() {
        // Has a move left, so nothing gets shuffled afterwards.
        let board = Board.parse([
            "lR G B",
            "G B R",
            "R G G",
        ])
        let lockedID = board[Position(0, 0)]!.id
        let game = Game(level: testLevel(), board: board)
        let result = game.useHammer(at: Position(0, 0))
        XCTAssertEqual(result.steps[0].locksBroken, [Position(0, 0)])
        XCTAssertFalse(game.board.cell(Position(0, 0)).locked)
        XCTAssertEqual(game.board[Position(0, 0)]?.id, lockedID)
    }

    func testHammerDamagesBlocker() {
        let board = Board.parse([
            "X2 G B",
            "G B R",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.useHammer(at: Position(0, 0))
        XCTAssertEqual(result.steps[0].damaged.map(\.piece.kind), [.blocker(hits: 1)])
        XCTAssertEqual(game.board[Position(0, 0)]?.kind, .blocker(hits: 1))
    }

    func testHammerFiresSpecialCandy() {
        let board = Board.parse([
            "R- G B Y",
            "G B Y R",
        ])
        let game = Game(level: testLevel(), board: board)
        let result = game.useHammer(at: Position(0, 0))
        let step = result.steps[0]
        XCTAssertTrue(step.activations.contains { $0.kind == .lineHorizontal })
        XCTAssertEqual(Set(step.cleared.map(\.position)).filter { $0.row == 0 }.count, 4)
    }

    func testHammerLeavesIngredientsAlone() {
        let board = Board.parse([
            "I G B",
            "G B R",
        ])
        let game = Game(level: testLevel(goals: [.collectIngredients(1)]), board: board)
        XCTAssertFalse(game.canHammer(Position(0, 0)))
        let result = game.useHammer(at: Position(0, 0))
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(game.board, board)
    }

    func testHammerDoesNotLetChocolateSpread() {
        let board = Board.parse([
            "C G B",
            "G B R",
            "B R G",
        ])
        let game = Game(level: testLevel(goals: [.clearChocolate]), board: board)
        let result = game.useHammer(at: Position(2, 2))
        XCTAssertNil(result.chocolateSpread)
        XCTAssertLessThanOrEqual(game.board.count { $0.isChocolate }, 1)
    }

    func testHammerCanWinTheLevel() {
        let board = Board.parse([
            "jR G B",
            "G B R",
            "B R G",
        ])
        let game = Game(level: testLevel(goals: [.clearJelly]), board: board)
        let result = game.useHammer(at: Position(0, 0))
        XCTAssertEqual(result.status, .won)
        XCTAssertEqual(game.movesLeft, 0, "leftover moves go into the sugar rush")
        XCTAssertFalse(game.canHammer(Position(1, 1)), "no boosters after the level is over")
    }

    // MARK: Extra moves

    func testExtraMovesContinueALostLevel() {
        let board = Board.parse([
            "R G R",
            "B R Y",
        ])
        let game = Game(level: testLevel(moves: 1), board: board)
        game.swap(Position(1, 1), Position(0, 1))
        XCTAssertEqual(game.status, .lost)
        game.addMoves(5)
        XCTAssertEqual(game.status, .playing)
        XCTAssertEqual(game.movesLeft, 5)
        XCTAssertNotNil(game.hint(), "the revived board must have a move")
    }

    func testExtraMovesBeforeTheStart() {
        let game = Game(level: Level.campaign[0], seed: 3)
        let moves = game.movesLeft
        game.addMoves(5)
        XCTAssertEqual(game.movesLeft, moves + 5)
    }

    func testNoExtraMovesAfterWinning() {
        let board = Board.parse([
            "jR G B",
            "G B R",
            "B R G",
        ])
        let game = Game(level: testLevel(goals: [.clearJelly]), board: board)
        game.useHammer(at: Position(0, 0))
        XCTAssertEqual(game.status, .won)
        game.addMoves(5)
        XCTAssertEqual(game.movesLeft, 0)
        XCTAssertEqual(game.status, .won)
    }

    // MARK: Colour mixer

    func testColorMixerShufflesWithoutSpendingAMove() {
        let board = Board.parse([
            "R G B Y",
            "B Y R G",
            "R G B Y",
            "B Y R G",
        ])
        let game = Game(level: testLevel(), board: board)
        let mixed = game.useColorMixer()
        XCTAssertNotNil(mixed)
        XCTAssertEqual(game.movesLeft, 10)
        XCTAssertFalse(MatchFinder.hasAnyMatch(in: game.board))
        XCTAssertNotNil(MatchFinder.findPossibleMove(in: game.board))
        XCTAssertEqual(Set(game.board.allPieces.map(\.1.id)), Set(board.allPieces.map(\.1.id)))
    }

    func testColorMixerKeepsFixedPiecesInPlace() {
        let board = Board.parse([
            "C G B Y",
            "B Y R G",
            "R lG B Y",
            "B Y R X2",
        ])
        let game = Game(level: testLevel(), board: board)
        game.useColorMixer()
        XCTAssertEqual(game.board[Position(0, 0)]?.kind, .chocolate)
        XCTAssertEqual(game.board[Position(3, 3)]?.kind, .blocker(hits: 2))
        XCTAssertEqual(game.board[Position(2, 1)]?.id, board[Position(2, 1)]?.id, "locked candy stays")
    }

    func testBoostersWorkOnEveryHandmadeLevel() {
        for level in Level.campaign where level.id < LevelGenerator.firstID {
            let game = Game(level: level, seed: 11)
            if let p = game.board.positions.first(where: game.canHammer) {
                let result = game.useHammer(at: p)
                XCTAssertTrue(result.isValid, "level \(level.id)")
                XCTAssertFalse(MatchFinder.hasAnyMatch(in: game.board), "level \(level.id)\n\(game.board)")
            }
            if game.status == .playing {
                XCTAssertNotNil(game.useColorMixer(), "level \(level.id)")
                XCTAssertNotNil(game.hint(), "level \(level.id)")
            }
        }
    }
}
