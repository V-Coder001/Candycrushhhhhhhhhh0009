import Match3Core
import SwiftUI

@main
struct SoettApp: App {
    @StateObject private var progress = ProgressStore()

    init() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.sound: true,
            SettingsKey.music: true,
            SettingsKey.voice: true,
            SettingsKey.haptics: true,
        ])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(progress)
        }
    }
}

/// Launch arguments for screenshots and demos, e.g. `-demoLevel 3 -demoSeed 7 -autoplay YES`.
enum Demo {
    static var level: Level? {
        let id = UserDefaults.standard.integer(forKey: "demoLevel")
        return (Level.campaign + Level.mixLab).first { $0.id == id }
    }

    static var seed: UInt64? {
        let seed = UserDefaults.standard.integer(forKey: "demoSeed")
        return seed > 0 ? UInt64(seed) : nil
    }

    static var autoplay: Bool { UserDefaults.standard.bool(forKey: "autoplay") }

    /// Opens the Mischlabor sheet.
    static var lab: Bool { UserDefaults.standard.bool(forKey: "demoLab") }

    /// Opens the start card of this level on the map.
    static var intro: Level? {
        let id = UserDefaults.standard.integer(forKey: "demoIntro")
        return Level.campaign.first { $0.id == id }
    }
}

enum SettingsKey {
    static let sound = "sound"
    static let music = "music"
    static let voice = "voice"
    static let haptics = "haptics"
}
