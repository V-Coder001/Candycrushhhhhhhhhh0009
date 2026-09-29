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

enum SettingsKey {
    static let sound = "sound"
    static let voice = "voice"
    static let haptics = "haptics"
}
