import Foundation
import UIKit

struct World {
    var userDefaults = UserDefaults.standard
    var notificationsController = NotificationsController()
    var colors = Colors()
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
            return .systemBackground
        } else {
            return .black
        }
    }

    var systemGroupedBackground: UIColor {
        if #available(iOS 13.0, *) {
            return .systemGroupedBackground
        } else {
            return .groupTableViewBackground
        }
    }
}

var Current = World()
