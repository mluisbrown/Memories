//
//  NotificationManager.swift
//  Memories
//
//  Created by Michael Brown on 07/09/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import Foundation
import UIKit
import Photos
import PHAssetHelper
import UserNotifications
import ReactiveSwift
import Result

class NotificationManager {
    struct Key {
        static let hasPromptedForUserNotifications = "HasPromptedForUserNotifications"
        static let notificationTime = "NotificationTime"
        static let notificationsEnabled = "NotificationsEnabled"
        static let notificationLaunchDate = "NotificationLaunchDate"
    }    
    
    /// registers the notification types the app would like. If the user has allowed 
    /// notifications this will result in scheduleNotifications() being called from 
    /// AppDelegate.application:didRegisterUserNotificationSettings
    static func registerSettings() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            UserDefaults.standard.set(true, forKey: Key.hasPromptedForUserNotifications)
        }
    }
    
    /// returns whether Notifications are allowed for this app at the System level
    static func notificationsAllowed() -> SignalProducer<Bool, NoError> {
        return SignalProducer { observer, _ in
            UNUserNotificationCenter.current().getNotificationSettings() { settings in
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
    
    static func launchDate() -> Date? {
        if let date = UserDefaults.standard.object(forKey: Key.notificationLaunchDate) as? Date {
            // clear the date as soon as it's read
            setLaunchDate(nil)
            return date
        }
        
        return nil
    }
    
    static func setLaunchDate(_ launchDate: Date?) {
        if let date = launchDate {
            UserDefaults.standard.set(date, forKey: Key.notificationLaunchDate)
        } else {
            UserDefaults.standard.removeObject(forKey: Key.notificationLaunchDate)
        }
    }
    
    /// returns whether the user has been prompted with the system "Allow Notifications" prompt
    static func hasPromptedForUserNotification() -> Bool {
        return UserDefaults.standard.bool(forKey: Key.hasPromptedForUserNotifications)
    }
    
    /// returns whether the user has requested notifications to be enabled
    static func notificationsEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: Key.notificationsEnabled)
    }
    
    /// returns the current notification time from the user defaults
    static func notificationTime() -> (hour: Int, minute: Int) {
        let notificationTime = UserDefaults.standard.integer(forKey: Key.notificationTime)
        let notificationHour = notificationTime / 100
        let notificationMinute = notificationTime - notificationHour * 100
        
        return (notificationHour, notificationMinute)
    }
    
    /// sets the current notification time in the user defaults
    static func setNotificationTime(_ hour: Int, _ minute: Int) {
        UserDefaults.standard.set(hour * 100 + minute, forKey: Key.notificationTime)
    }
    
    /// attempts to enable notifications, prompting the user for authorization if required
    static func enableNotifications() {
        UserDefaults.standard.set(true, forKey: Key.notificationsEnabled)
        
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

                UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
            }
    }
    
    /// disables all notifications
    static func disableNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UserDefaults.standard.set(false, forKey: Key.notificationsEnabled)
    }
    
    /// schedules notifications, runs on a background thread
    static func scheduleNotifications() {
        guard notificationsEnabled() else { return }

        notificationsAllowed()
            .filter { $0 }
            .startWithValues { _ in
                let operation = BlockOperation { () -> Void in
                    scheduleNotifications(with: PHAssetHelper().datesMap())
                }

                let queue = OperationQueue()
                queue.addOperation(operation)
            }
    }
    
    private static func scheduleNotifications(with datesMap: [Date:Int]) {
        let bodyFormatString = NSLocalizedString("You have %lu photo memories for today", comment: "")
        let titleFormatString = NSLocalizedString("%lu Photo Memories", comment: "")

        let gregorian = Date.gregorianCalendar
        let todayComps = gregorian.dateComponents([.year, .month, .day], from: Date())
        let todayKey = todayComps.month! * 100 + todayComps.day!
        let currentYear = todayComps.year!
        let time = notificationTime()
        
        // have to force result of prefix() to Array
        // due to bug in Swift 3.0: https://bugs.swift.org/browse/SR-1856

        let notifications : [UNNotificationRequest] = Array(datesMap.map { (date: Date, count: Int) -> (date: Date, count: Int) in
            // adjust dates so that any date earlier than today has the
            // following year as its notification date
            let comps = gregorian.dateComponents([.month, .day], from: date)
            let key = comps.month! * 100 + comps.day!
            let notificationYear = key >= todayKey ? currentYear : currentYear + 1
            let notificationDate = gregorian.date(from: DateComponents(era: 1, year: notificationYear, month: comps.month!, day: comps.day!, hour: time.hour, minute: time.minute, second: 0, nanosecond: 0))!

            return (date: notificationDate, count: count)
        }.sorted {
            // sort in ascending order of date
            $0.date.compare($1.date) == .orderedAscending
        }.prefix(64)).map {
            let content = UNMutableNotificationContent()
            content.sound = UNNotificationSound(named: UNNotificationSoundName("notification.mp3"))
            content.title = String(format: titleFormatString, $0.count)
            content.body = String(format: bodyFormatString, $0.count)

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: $0.date),
                repeats: false
            )

            return UNNotificationRequest(identifier: "\($0.date)", content: content, trigger: trigger)
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

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "\(noteTime)", content: testNote.content, trigger: trigger)
        )
#else
        notifications.forEach {
            UNUserNotificationCenter.current().add($0)
        }
#endif
    }
}


class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        NotificationManager.setLaunchDate(response.notification.date)
        completionHandler()
    }
}
