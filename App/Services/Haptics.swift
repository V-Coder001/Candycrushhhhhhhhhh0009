import UIKit

@MainActor
enum Haptics {
    private static var enabled: Bool { UserDefaults.standard.bool(forKey: SettingsKey.haptics) }

    static func tap() { impact(.soft, intensity: 0.5) }
    static func pop() { impact(.light, intensity: 0.6) }
    static func special() { impact(.medium, intensity: 0.8) }
    static func explosion() { impact(.rigid, intensity: 1) }

    static func invalid() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
    }
}
