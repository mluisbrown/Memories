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
        if #available(iOS 13.0, *) {
            return .label
        } else {
            return .white
        }
    }

    var systemBackground: UIColor {
        if #available(iOS 13.0, *) {
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
        } else {
            return .black
        }
    }

    var systemGroupedBackground: UIColor {
        if #available(iOS 13.0, *) {
            return .systemGroupedBackground
        } else {
            return .init(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        }
    }

    var opaqueSeparator: UIColor {
        if #available(iOS 13.0, *) {
            return .opaqueSeparator
        } else {
            return .init(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        }
    }
}

var Current = World()
