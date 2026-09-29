import XCTest
@testable import Match3Core

final class MixingTests: XCTestCase {
    private func mixLevel(goals: [Goal] = [.serveMixes(10)], mixing: Bool = true) -> Level {
        Level(id: 0, name: "Test", moves: 10, colors: 5, goals: goals, starScores: [1, 2, 3],
              layout: [], mixing: mixing)
    }

    /// Row 1 turns into R R R | Y Y Y: two touching matches of different colours.
    private let doubleMatch = Board.parse([
        "G B G B G B",
        "R R Y R Y Y",
        "B G B G B G",
    ])

    func testDoubleMatchLeavesMixedCandyAtSwappedCell() {
        let game = Game(level: mixLevel(), board: doubleMatch)
        let result = game.swap(Position(1, 2), Position(1, 3))
        XCTAssertTrue(result.isValid)
        let created = result.steps[0].created
        XCTAssertEqual(created.map(\.piece.kind), [.mix(.red, .yellow)])
        XCTAssertEqual(created.first?.position, Position(1, 3))
    }

    func testMixHintFindsTheDoubleMatch() {
        let game = Game(level: mixLevel(), board: doubleMatch)
        let hint = game.mixHint()
        XCTAssertEqual(hint.map { [$0.0, $0.1] }, [Position(1, 2), Position(1, 3)])
        XCTAssertNil(Game(level: mixLevel(mixing: false), board: doubleMatch).mixHint())
    }

    func testNoMixingOutsideTheLab() {
        let game = Game(level: mixLevel(mixing: false), board: doubleMatch)
        let result = game.swap(Position(1, 2), Position(1, 3))
        XCTAssertFalse(result.steps.flatMap(\.created).contains { $0.piece.kind.isMix })
    }

    func testMixedCandyMatchesEitherColourAndIsServed() {
        let board = Board.parse([
            "G B G B G",
            "R %RY B Y Y",
            "B G R G B",
        ])
        XCTAssertFalse(MatchFinder.hasAnyMatch(in: board))
        let game = Game(level: mixLevel(), board: board)
        let result = game.swap(Position(1, 2), Position(2, 2))
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.steps[0].served.map(\.piece.kind), [.mix(.red, .yellow)])
        XCTAssertEqual(game.mixesServed, 1)
        XCTAssertEqual(game.goalProgress.first?.current, 1)
    }

    func testMixedCandyBridgesTwoColours() {
        // The mixed candy completes a red line and a yellow column at the same time.
        let board = Board.parse([
            "G B Y B G",
            "O B Y O B",
            "R R %RY G P",
        ])
        let groups = MatchFinder.findMatches(in: board)
        XCTAssertEqual(groups.count, 1, "one group joined through the mixed candy")
        XCTAssertEqual(groups.first?.positions.count, 5)
    }

    func testColourBombAlsoServesMixedCandiesOfThatColour() {
        let board = Board.parse([
            "G B G B G",
            "O %RY B * R",
            "B G O G B",
        ])
        let game = Game(level: mixLevel(), board: board)
        game.swap(Position(1, 3), Position(1, 4))
        XCTAssertEqual(game.mixesServed, 1)
    }

    func testMixedCandyRoundTripsThroughText() {
        let board = Board.parse(["%YR G B"])
        XCTAssertEqual(board[Position(0, 0)]?.kind, .mix(.red, .yellow))
        XCTAssertEqual(board.textRows, ["%RY G B"])
    }

    func testLabLevelsArePlayable() {
        for level in Level.mixLab {
            XCTAssertTrue(level.mixing)
            XCTAssertTrue(level.goals.contains { if case .serveMixes = $0 { return true } else { return false } })
            XCTAssertGreaterThanOrEqual(level.id, Level.mixLabFirstID)
            for seed in 1...10 as ClosedRange<UInt64> {
                let game = Game(level: level, seed: seed)
                XCTAssertNotNil(game.hint(), "\(level.name) seed \(seed)")
                var moves = 0
                while game.status == .playing, moves < 15, let (a, b) = game.hint() {
                    XCTAssertTrue(game.swap(a, b).isValid)
                    XCTAssertFalse(MatchFinder.hasAnyMatch(in: game.board), "\(level.name) seed \(seed)")
                    moves += 1
                }
            }
        }
    }
}
