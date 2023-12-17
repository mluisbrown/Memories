import Foundation
import UIKit
import Core
import Photos
import PHAssetHelper
import UserNotifications
import ReactiveSwift

struct NotificationsController {
    struct Key {
        static let hasPromptedForUserNotifications = "HasPromptedForUserNotifications"
        static let notificationTime = "NotificationTime"
        static let notificationsEnabled = "NotificationsEnabled"
        static let notificationLaunchDate = "NotificationLaunchDate"
    }    

    let notificationCenter = UNUserNotificationCenter.current()

    func registerSettings() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            Current.userDefaults.set(true, forKey: Key.hasPromptedForUserNotifications)
        }
    }
    
    /// returns whether Notifications are allowed for this app at the System level
    func notificationsAllowed() -> SignalProducer<Bool, Never> {
        return SignalProducer { [notificationCenter] observer, _ in
            notificationCenter.getNotificationSettings() { settings in
                switch settings.alertSetting {
                case .enabled:
                    observer.send(value: true)
                default:
                    observer.send(value: false)
                }

                observer.sendCompleted()
            }
        }
    }
    
    func launchDate() -> Date? {
        if let date = Current.userDefaults.object(forKey: Key.notificationLaunchDate) as? Date {
            // clear the date as soon as it's read
            setLaunchDate(nil)
            return date
        }
        
        return nil
    }
    
    func setLaunchDate(_ launchDate: Date?) {
        if let date = launchDate {
            Current.userDefaults.set(date, forKey: Key.notificationLaunchDate)
        } else {
            Current.userDefaults.removeObject(forKey: Key.notificationLaunchDate)
        }
    }
    
    /// returns whether the user has been prompted with the system "Allow Notifications" prompt
    func hasPromptedForUserNotification() -> Bool {
        return Current.userDefaults.bool(forKey: Key.hasPromptedForUserNotifications)
    }
    
    /// returns whether the user has requested notifications to be enabled
    func notificationsEnabled() -> Bool {
        return Current.userDefaults.bool(forKey: Key.notificationsEnabled)
    }
    
    /// returns the current notification time from the user defaults
    func notificationTime() -> (hour: Int, minute: Int) {
        let notificationTime = Current.userDefaults.integer(forKey: Key.notificationTime)
        let notificationHour = notificationTime / 100
        let notificationMinute = notificationTime - notificationHour * 100
        
        return (notificationHour, notificationMinute)
    }
    
    /// sets the current notification time in the user defaults
    func setNotificationTime(_ hour: Int, _ minute: Int) {
        Current.userDefaults.set(hour * 100 + minute, forKey: Key.notificationTime)
    }
    
    /// attempts to enable notifications, prompting the user for authorization if required
    func enableNotifications() {
        Current.userDefaults.set(true, forKey: Key.notificationsEnabled)
        
        // if the user has never been prompted for allowing notifications
        // register for notifications to force the prompt
        if !hasPromptedForUserNotification() {
            registerSettings()
            return
        }
        
        // if the user has disabled notifications in Settings
        // give them the opportunity to go to settings
        notificationsAllowed()
            .observe(on: UIScheduler())
            .filter((!))
            .startWithValues { _ in
                let alert = UIAlertController(title: NSLocalizedString("Notifications Disabled", comment: ""), message: NSLocalizedString("You have disabled notifications for Memories. If you want to receive notifications you need to enable this access in Settings. Would you like to do this now?", comment: ""), preferredStyle: .alert)
                let settings = UIAlertAction(title: NSLocalizedString("Settings", comment: ""), style: .default, handler: { (action) -> Void in
                    let url = URL(string: UIApplication.openSettingsURLString)!
                    UIApplication.shared.open(url)
                })
                let nothanks = UIAlertAction(title: NSLocalizedString("No thanks", comment: ""), style: .cancel, handler: { (action) -> Void in

                })
                alert.addAction(nothanks)
                alert.addAction(settings)

                UIApplication
                    .shared
                    .connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                    .last?.rootViewController?.present(alert, animated: true, completion: nil)
            }
    }
    
    /// disables all notifications
    func disableNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        Current.userDefaults.set(false, forKey: Key.notificationsEnabled)
    }
    
    /// schedules notifications, runs on a background thread
    func scheduleNotifications() {
        guard notificationsEnabled() else { return }

        notificationsAllowed()
            .filter { $0 }
            .startWithValues { _ in
                let operation = BlockOperation { () -> Void in
                    self.scheduleNotifications(with: PHAssetHelper().datesMap())
                }

                let queue = OperationQueue()
                queue.addOperation(operation)
            }
    }
    
    private func scheduleNotifications(with datesMap: [Date:Int]) {
        let bodyFormatString = NSLocalizedString("You have %lu photo memories for today", comment: "")
        let titleFormatString = NSLocalizedString("%lu Photo Memories", comment: "")

        let gregorian = Date.gregorianCalendar
        let todayComps = gregorian.dateComponents([.year, .month, .day], from: Date())
        let todayKey = todayComps.month! * 100 + todayComps.day!
        let currentYear = todayComps.year!
        let time = notificationTime()
        
        let notifications : [UNNotificationRequest] = datesMap.map { (date: Date, count: Int) -> (date: Date, count: Int) in
            // adjust dates so that any date earlier than today has the
            // following year as its notification date
            let comps = gregorian.dateComponents([.month, .day], from: date)
            let key = comps.month! * 100 + comps.day!
            let notificationYear = key >= todayKey ? currentYear : currentYear + 1
            let notificationDate = gregorian.date(from: DateComponents(era: 1, year: notificationYear, month: comps.month!, day: comps.day!, hour: time.hour, minute: time.minute, second: 0, nanosecond: 0))!

            return (date: notificationDate, count: count)
        }.sorted {
            $0.date.compare($1.date) == .orderedAscending
        }.prefix(64).map { (date, count) in
            let content = UNMutableNotificationContent()
            content.sound = UNNotificationSound(named: UNNotificationSoundName("notification.mp3"))
            content.title = String(format: titleFormatString, count)
            content.body = String(format: bodyFormatString, count)

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date),
                repeats: false
            )

            return UNNotificationRequest(identifier: "\(date)", content: content, trigger: trigger)
        }

        guard notifications.count > 0 else { return }

#if targetEnvironment(simulator)
        guard let testNote = notifications.first else { return }
        let now = Date()
        let noteTime = now.addingTimeInterval(20)

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: noteTime),
            repeats: false
        )

        notificationCenter.add(
            UNNotificationRequest(identifier: "\(noteTime)", content: testNote.content, trigger: trigger)
        )
#else
        notifications.forEach {
            notificationCenter.add($0)
        }
#endif
    }
}


class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Current.notificationsController.setLaunchDate(response.notification.date)
        completionHandler()
    }
}
