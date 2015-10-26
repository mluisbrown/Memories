//
//  AppDelegate.swift
//  Memories
//
//  Created by Michael Brown on 18/06/2015.
//  Copyright (c) 2015 Michael Brown. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        Fabric.with([Crashlytics.self])
        
        UINavigationBar.appearance().titleTextAttributes = [NSFontAttributeName : UIFont.systemFontOfSize(16)]
        
        NSUserDefaults.standardUserDefaults().registerDefaults([NotificationManager.NOTIFICATION_TIME_KEY : 1000,
            NotificationManager.HAS_PROMPTED_KEY : false,
            NotificationManager.NOTIFICATIONS_ENABLED_KEY: false])

        // store the date of the notification that launched the app (if any)
        // so that we start the view controller with that date
        if let notification = launchOptions?[UIApplicationLaunchOptionsLocalNotificationKey] as? UILocalNotification {
            NotificationManager.setLaunchDate(notification.fireDate)
        }
        
        // this will schedule notifications if they are allowed and enabled
        NotificationManager.scheduleNotifications()
        
        return true
    }

    func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        if application.applicationState != .Active {
            NotificationManager.setLaunchDate(notification.fireDate)
        }
    }
    
    // MARK: Notification Settings
    
    func application(application: UIApplication, didRegisterUserNotificationSettings notificationSettings: UIUserNotificationSettings) {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: NotificationManager.HAS_PROMPTED_KEY)
        NSUserDefaults.standardUserDefaults().synchronize()
    }

}

