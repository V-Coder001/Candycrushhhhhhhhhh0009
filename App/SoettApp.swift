import Match3Core
import SwiftUI

@main
struct SoettApp: App {
    @StateObject private var progress = ProgressStore()

    init() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.sound: true,
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
        return Level.campaign.first { $0.id == id }
    }

    static var seed: UInt64? {
        let seed = UserDefaults.standard.integer(forKey: "demoSeed")
        return seed > 0 ? UInt64(seed) : nil
    }

    static var autoplay: Bool { UserDefaults.standard.bool(forKey: "autoplay") }
}

enum SettingsKey {
    static let sound = "sound"
    static let voice = "voice"
    static let haptics = "haptics"
}
