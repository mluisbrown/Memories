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

class NotificationManager {
    static let HAS_PROMPTED_KEY = "HasPromptedForUserNotifications"
    static let NOTIFICATION_TIME_KEY = "NotificationTime"
    static let NOTIFICATIONS_ENABLED_KEY = "NotificationsEnabled"
    static let NOTIFICATION_LANUCH_DATE_KEY = "NotificationLaunchDate"
    
    /// registers the notification types the app would like. If the user has allowed 
    /// notifications this will result in scheduleNotifications() being called from 
    /// AppDelegate.application:didRegisterUserNotificationSettings
    static func registerSettings() {
        let settings = UIUserNotificationSettings(forTypes: [.Badge, .Alert, .Sound], categories: nil)
        UIApplication.sharedApplication().registerUserNotificationSettings(settings)
    }
    
    /// returns whether Notifications are allowed for this app at the System level
    static func notificationsAllowed() -> Bool {
        if let types = UIApplication.sharedApplication().currentUserNotificationSettings()?.types {
            if types.contains(.Alert) {
                return true
            }
        }
        
        return false
    }
    
    static func launchDate() -> NSDate? {
        if let date = NSUserDefaults.standardUserDefaults().objectForKey(NOTIFICATION_LANUCH_DATE_KEY) as? NSDate {
            // clear the date as soon as it's read
            setLaunchDate(nil)
            return date
        }
        
        return nil
    }
    
    static func setLaunchDate(launchDate: NSDate?) {
        if let date = launchDate {
            NSUserDefaults.standardUserDefaults().setObject(date, forKey: NOTIFICATION_LANUCH_DATE_KEY)
        } else {
            NSUserDefaults.standardUserDefaults().removeObjectForKey(NOTIFICATION_LANUCH_DATE_KEY)
        }
        
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    /// returns whether the user has been prompted with the system "Allow Notifications" prompt
    static func hasPromptedForUserNotification() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey(HAS_PROMPTED_KEY)
    }
    
    /// returns whether the user has requested notifications to be enabled
    static func notificationsEnabled() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey(NOTIFICATIONS_ENABLED_KEY)
    }
    
    /// returns the current notification time from the user defaults
    static func notificationTime() -> (hour: Int, minute: Int) {
        let notificationTime = NSUserDefaults.standardUserDefaults().integerForKey(NOTIFICATION_TIME_KEY)
        let notificationHour = notificationTime / 100
        let notificationMinute = notificationTime - notificationHour * 100
        
        return (notificationHour, notificationMinute)
    }
    
    /// sets the current notification time in the user defaults
    static func setNotificationTime(hour: Int, _ minute: Int) {
        NSUserDefaults.standardUserDefaults().setInteger(hour * 100 + minute, forKey: NOTIFICATION_TIME_KEY)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    /// attempts to enable notifications, prompting the user for authorization if required
    static func enableNotifications() {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: NOTIFICATIONS_ENABLED_KEY)
        NSUserDefaults.standardUserDefaults().synchronize()
        
        // if the user has never been prompted for allowing notifications
        // register for notifications to force the prompt
        if !hasPromptedForUserNotification() {
            registerSettings()
            return
        }
        
        // if the user has disabled notifications in Settings
        // give them the opportunity to go to settings
        if !notificationsAllowed() {
            let alert = UIAlertController(title: NSLocalizedString("Notifications Disabled", comment: ""), message: NSLocalizedString("You have disabled notifications for Memories. If you want to receive notifications you need to enable this access in Settings. Would you like to do this now?", comment: ""), preferredStyle: .Alert)
            let settings = UIAlertAction(title: NSLocalizedString("Settings", comment: ""), style: .Default, handler: { (action) -> Void in
                let url = NSURL(string: UIApplicationOpenSettingsURLString)
                UIApplication.sharedApplication().openURL(url!);
            })
            let nothanks = UIAlertAction(title: NSLocalizedString("No thanks", comment: ""), style: .Cancel, handler: { (action) -> Void in
                
            })
            alert.addAction(nothanks)
            alert.addAction(settings)
            
            UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    /// disables all notifications
    static func disableNotifications() {
        UIApplication.sharedApplication().cancelAllLocalNotifications()
        
        NSUserDefaults.standardUserDefaults().setBool(false, forKey: NOTIFICATIONS_ENABLED_KEY)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    /// schedules notifications, runs on a background thread
    static func scheduleNotifications() {
        guard notificationsAllowed() && notificationsEnabled() else { return }
        
        let operation = NSBlockOperation { () -> Void in
            scheduleNotificationsWithDatesMap(buildDatesMap())
        }

        let queue = NSOperationQueue()
        queue.addOperation(operation)
    }
    
    private static func buildDatesMap() -> [NSDate : Int] {
        var datesMap = [NSDate : Int]()

        // don't want to trigger a "Allow Photos?"
        // prompt whilst scheduling notificaions
        guard PHPhotoLibrary.authorizationStatus() == .Authorized else {
            return datesMap
        }
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetchResult = PHAsset.fetchAssetsWithMediaType(.Image, options: options)
        
        
        let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
        let todayComps = gregorian.components([.Year, .Month, .Day], fromDate: NSDate())
        let todayKey = todayComps.month * 100 + todayComps.day
        let currentYear = todayComps.year
        
        let time = notificationTime()
        
        fetchResult.enumerateObjectsUsingBlock { (object, index, stop) -> Void in
            let asset : PHAsset = object as! PHAsset
            let comps = gregorian.components([.Month, .Day], fromDate: asset.creationDate!)
            let key = comps.month * 100 + comps.day
            let notificationYear = key >= todayKey ? currentYear : currentYear + 1
            
            let date = gregorian.dateWithEra(1, year: notificationYear, month: comps.month, day: comps.day, hour: time.hour, minute: time.minute, second: 0, nanosecond: 0)!
            
            if let entry = datesMap[date] {
                datesMap[date] = entry + 1
            } else {
                datesMap[date] = 1
            }
        }
        
        NSLog("datesMap has \(datesMap.count) entries.")
        return datesMap
    }
    
    private static func scheduleNotificationsWithDatesMap(datesMap: [NSDate:Int]) {
        let timeZone = NSTimeZone.systemTimeZone()
        let bodyFormatString = NSLocalizedString("You have %lu photo memories for today", comment: "")
        let titleFormatString = NSLocalizedString("%lu Photo Memories", comment: "")
        
        let notifications : [UILocalNotification] = datesMap.map {
            // transform into array of date, count tuples
            (date: $0.0, count: $0.1)
        }.sort {
            // sort in ascending order of date
            $0.date.compare($1.date) == .OrderedAscending
        }.prefix(64).map {
            // get first 64 items and transform to array of UILocalNotification
            let notification = UILocalNotification()
            notification.fireDate = $0.date
            notification.timeZone = timeZone
            notification.soundName = "notification.mp3"
            notification.alertBody = String(format: bodyFormatString, $0.count)
            notification.alertTitle = String(format: titleFormatString, $0.count)
            return notification
        }

        UIApplication.sharedApplication().cancelAllLocalNotifications()
        guard notifications.count > 0 else {return}

#if (arch(i386) || arch(x86_64)) && os(iOS)
        let testNote = notifications.first
        let now = NSDate()
        let noteTime = now.dateByAddingTimeInterval(20)
        testNote?.fireDate = noteTime

        UIApplication.sharedApplication().scheduledLocalNotifications = [testNote!]
#else
        // schedule the new notifications
        UIApplication.sharedApplication().scheduledLocalNotifications = notifications
#endif
    }
    
}