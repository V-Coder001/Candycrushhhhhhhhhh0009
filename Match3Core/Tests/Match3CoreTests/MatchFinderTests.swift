import XCTest
@testable import Match3Core

final class MatchFinderTests: XCTestCase {
    func testParseRoundTrip() {
        let rows = [
            "R G B Y",
            "jR lG kB X2",
            "* C I _",
            "R- G| B@ Y>",
        ]
        let board = Board.parse(rows)
        XCTAssertEqual(board.rows, 4)
        XCTAssertEqual(board.columns, 4)
        XCTAssertEqual(board.textRows, rows)
        XCTAssertEqual(board.cell(Position(1, 0)).jelly, 1)
        XCTAssertTrue(board.cell(Position(1, 1)).locked)
        XCTAssertEqual(board.cell(Position(1, 2)).jelly, 2)
        XCTAssertEqual(board[Position(1, 3)]?.kind, .blocker(hits: 2))
        XCTAssertNil(board[Position(2, 3)])
    }

    func testNoMatch() {
        let board = Board.parse([
            "R G B",
            "G B R",
            "B R G",
        ])
        XCTAssertTrue(MatchFinder.findMatches(in: board).isEmpty)
        XCTAssertFalse(MatchFinder.hasAnyMatch(in: board))
    }

    func testHorizontalThree() {
        let board = Board.parse([
            "R R R",
            "G B G",
            "B G B",
        ])
        let groups = MatchFinder.findMatches(in: board)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].color, .red)
        XCTAssertEqual(groups[0].positions, [Position(0, 0), Position(0, 1), Position(0, 2)])
        XCTAssertEqual(groups[0].reward, .none)
    }

    func testVerticalThree() {
        let board = Board.parse([
            "G R B",
            "B R G",
            "G R B",
        ])
        let groups = MatchFinder.findMatches(in: board)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].longestVertical, 3)
        XCTAssertTrue(MatchFinder.hasMatch(at: Position(1, 1), in: board))
        XCTAssertFalse(MatchFinder.hasMatch(at: Position(0, 0), in: board))
    }

    func testFourInRowGivesStriped() {
        let board = Board.parse([
            "R R R R G",
            "G B G B B",
        ])
        let group = MatchFinder.findMatches(in: board)[0]
        XCTAssertEqual(group.reward, .striped(.horizontal))
        XCTAssertEqual(group.rewardKind, .candy(.red, .stripedVertical))
    }

    func testFiveInRowGivesColorBomb() {
        let board = Board.parse([
            "B",
            "B",
            "B",
            "B",
            "B",
            "G",
        ])
        let group = MatchFinder.findMatches(in: board)[0]
        XCTAssertEqual(group.reward, .colorBomb)
        XCTAssertEqual(group.rewardKind, .colorBomb)
    }

    func testLShapeGivesWrapped() {
        let board = Board.parse([
            "Y G B",
            "Y B G",
            "Y Y Y",
        ])
        let groups = MatchFinder.findMatches(in: board)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].positions.count, 5)
        XCTAssertEqual(groups[0].reward, .wrapped)
    }

    func testTShapeGivesWrapped() {
        let board = Board.parse([
            "P P P",
            "G P B",
            "B P G",
        ])
        XCTAssertEqual(MatchFinder.findMatches(in: board)[0].reward, .wrapped)
    }

    func testSquareGivesFish() {
        let board = Board.parse([
            "G G B",
            "G G R",
            "B R B",
        ])
        let groups = MatchFinder.findMatches(in: board)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].reward, .fish)
        XCTAssertTrue(MatchFinder.hasMatch(at: Position(1, 1), in: board))
    }

    func testSeparateMatchesStaySeparate() {
        let board = Board.parse([
            "R R R G",
            "G B G B",
            "B B B G",
        ])
        let groups = MatchFinder.findMatches(in: board)
        XCTAssertEqual(groups.map(\.color), [.red, .blue])
    }

    func testObstaclesAndIngredientsNeverMatch() {
        let board = Board.parse([
            "C C C",
            "I I I",
            "X2 X2 X2",
            "* * *",
        ])
        XCTAssertTrue(MatchFinder.findMatches(in: board).isEmpty)
    }

    func testValidSwap() {
        let board = Board.parse([
            "R G R",
            "G R G",
        ])
        XCTAssertTrue(MatchFinder.isValidSwap(Position(0, 1), Position(1, 1), in: board))
        XCTAssertFalse(MatchFinder.isValidSwap(Position(0, 0), Position(0, 1), in: board))
        XCTAssertFalse(MatchFinder.isValidSwap(Position(0, 0), Position(1, 1), in: board), "diagonal")
        XCTAssertFalse(MatchFinder.isValidSwap(Position(0, 0), Position(0, 2), in: board), "not adjacent")
    }

    func testLockedPieceCannotSwap() {
        let board = Board.parse([
            "R lG R",
            "G R G",
        ])
        XCTAssertFalse(MatchFinder.isValidSwap(Position(0, 1), Position(1, 1), in: board))
    }

    func testSpecialCombosAreAlwaysValid() {
        let board = Board.parse([
            "* G B",
            "R- B@ Y",
        ])
        XCTAssertTrue(MatchFinder.isValidSwap(Position(0, 0), Position(0, 1), in: board), "bomb + candy")
        XCTAssertTrue(MatchFinder.isValidSwap(Position(1, 0), Position(1, 1), in: board), "striped + wrapped")
        XCTAssertFalse(MatchFinder.isValidSwap(Position(1, 1), Position(1, 2), in: board), "wrapped + plain")
    }
}
