//
//  AppDelegate.swift
//  Memories
//
//  Created by Michael Brown on 18/06/2015.
//  Copyright (c) 2015 Michael Brown. All rights reserved.
//

import UIKit
import AVFoundation
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool {
        Fabric.with([Crashlytics.self])

        UpgradeManager.completeTransactions()
        
        UserDefaults.standard.register(defaults: [NotificationManager.Key.notificationTime : 1000,
            NotificationManager.Key.hasPromptedForUserNotifications : false,
            NotificationManager.Key.notificationsEnabled: false,
            UpgradeManager.Key.appLaunchCountMod3: 0])

        // store the date of the notification that launched the app (if any)
        // so that we start the view controller with that date
        if let notification = launchOptions?[UIApplicationLaunchOptionsKey.localNotification] as? UILocalNotification {
            NotificationManager.setLaunchDate(notification.fireDate)
        }
        
        // this will schedule notifications if they are allowed and enabled
        NotificationManager.scheduleNotifications()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            NSLog("AVAudioSession setCategory failed!")
        }
        
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        UpgradeManager.registerAppLaunch()        
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

