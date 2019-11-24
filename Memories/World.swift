import Foundation
import UIKit

struct World {
    var userDefaults = UserDefaults.standard
    var notificationsController = NotificationsController()

    var textColor: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.label
        } else {
            return UIColor.white
        }
    }

    var backgroundColor: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.systemBackground
        } else {
            return UIColor.black
        }
    }
}

var Current = World()
