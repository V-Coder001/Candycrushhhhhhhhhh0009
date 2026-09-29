extension Level {
    /// First id of the Mischlabor levels, far away from the campaign so progress never mixes up.
    public static let mixLabFirstID = 10_001

    /// Prototype levels for mixed candies. A swap that makes two touching matches of different colours
    /// leaves a two-tone candy at the swapped cell. It matches with either colour; popping it serves it.
    public static let mixLab: [Level] = [
        Level(id: 10_001, name: "Erste Mischung", moves: 20, colors: 5,
              goals: [.serveMixes(3)], starScores: [3_000, 14_000, 22_000],
              layout: [
                  ".........",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
              ], mixing: true),
        Level(id: 10_002, name: "Brausebonbons", moves: 22, colors: 5,
              goals: [.serveMixes(5)], starScores: [4_000, 16_000, 25_000],
              layout: [
                  "##.....##",
                  "#.......#",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
                  "#.......#",
                  "##.....##",
              ], mixing: true),
        Level(id: 10_003, name: "Mischen auf Gelee", moves: 26, colors: 5,
              goals: [.serveMixes(4), .clearJelly], starScores: [4_000, 22_000, 34_000],
              layout: [
                  ".........",
                  ".........",
                  "..jjjjj..",
                  "..jjjjj..",
                  "..jjjjj..",
                  "..jjjjj..",
                  ".........",
                  ".........",
                  ".........",
              ], mixing: true),
        Level(id: 10_004, name: "Bunte Tüte", moves: 26, colors: 6,
              goals: [.serveMixes(4)], starScores: [3_000, 12_000, 18_000],
              layout: [
                  ".........",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
              ], mixing: true),
        Level(id: 10_005, name: "Mischmeister", moves: 25, colors: 5,
              goals: [.serveMixes(8)], starScores: [5_000, 22_000, 33_000],
              layout: [
                  ".........",
                  ".........",
                  ".........",
                  "b..b.b..b",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
                  ".........",
              ], mixing: true),
    ]
}
