import Foundation
import UIKit

struct World {
    var userDefaults = UserDefaults.standard
    var notificationsController = NotificationsController()
    var colors = Colors()
    var updateAppearance: (Appearance) -> Void = { _ in }
}

struct Colors {
    var label: UIColor {
        .label
    }

    var systemBackground: UIColor {
        return UIColor { traits in
            switch traits.userInterfaceStyle {
            case .light, .unspecified:
                return .systemBackground
            case .dark:
                return .black
            @unknown default:
                return .systemBackground
            }
        }
    }

    var systemGroupedBackground: UIColor {
        .systemGroupedBackground
    }

    var opaqueSeparator: UIColor {
        .opaqueSeparator
    }
}

var Current = World()
