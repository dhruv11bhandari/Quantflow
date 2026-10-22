import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Thin wrappers over UIKit feedback generators. Everything is a no-op off-device, so the
/// logic layer can be compiled and tested anywhere.
enum Haptics {
    static var enabled = true

    static func tap() {
        #if canImport(UIKit)
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func soft() {
        #if canImport(UIKit)
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
        #endif
    }

    static func select() {
        #if canImport(UIKit)
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func success() {
        #if canImport(UIKit)
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if canImport(UIKit)
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    static func error() {
        #if canImport(UIKit)
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}

enum Platform {
    /// Mirrors the system "Reduce Motion" setting.
    static var reduceMotion: Bool {
        #if canImport(UIKit)
        return UIAccessibility.isReduceMotionEnabled
        #else
        return false
        #endif
    }
}
