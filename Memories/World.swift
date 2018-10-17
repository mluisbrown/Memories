import Foundation

struct World {
    var userDefaults = UserDefaults.standard
    var notificationsController = NotificationsController()
}

var Current = World()
