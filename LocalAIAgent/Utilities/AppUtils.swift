import Foundation
import UIKit

/// Utilitaires divers
enum AppUtils {

    // MARK: - Haptique

    static func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func hapticSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func hapticError() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Formatage

    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static func formatSpeed(_ tps: Double) -> String {
        return String(format: "%.1f tok/s", tps)
    }

    // MARK: - Modèle d'appareil

    static let deviceModelMap: [String: String] = [
        "iPhone15,2": "iPhone 15 Pro",
        "iPhone15,3": "iPhone 15 Pro Max",
        "iPhone16,1": "iPhone 16 Pro",
        "iPhone16,2": "iPhone 16 Pro Max",
        "iPhone14,2": "iPhone 14 Pro",
        "iPhone14,3": "iPhone 14 Pro Max",
        "iPhone14,4": "iPhone 14",
        "iPhone14,5": "iPhone 14 Plus",
        "iPhone14,7": "iPhone 15",
        "iPhone14,8": "iPhone 15 Plus",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone15,4": "iPhone 16",
        "iPhone15,5": "iPhone 16 Plus",
    ]

    static var friendlyDeviceName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.compactMap { element in
            guard let value = element.value as? Int8, value != 0 else { return nil }
            return String(UnicodeScalar(UInt8(value)))
        }.joined()
        return deviceModelMap[identifier] ?? "iPhone"
    }
}
