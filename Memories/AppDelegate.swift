//
//  AppDelegate.swift
//  Memories
//
//  Created by Michael Brown on 18/06/2015.
//  Copyright (c) 2015 Michael Brown. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        UserDefaults.standard.register([NotificationManager.Key.notificationTime : 1000,
            NotificationManager.Key.hasPromptedForUserNotifications : false,
            NotificationManager.Key.notificationsEnabled: false])

        // store the date of the notification that launched the app (if any)
        // so that we start the view controller with that date
        if let notification = launchOptions?[UIApplicationLaunchOptionsLocalNotificationKey] as? UILocalNotification {
            NotificationManager.setLaunchDate(notification.fireDate)
        }
        
        // this will schedule notifications if they are allowed and enabled
        NotificationManager.scheduleNotifications()
        
        return true
    }

    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        if application.applicationState != .active {
            NotificationManager.setLaunchDate(notification.fireDate)
        }
    }
    
    // MARK: Notification Settings
    
    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        UserDefaults.standard.set(true, forKey: NotificationManager.Key.hasPromptedForUserNotifications)
    }

}

