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
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var notificationDelegate = NotificationCenterDelegate()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
        Fabric.with([Crashlytics.self])

        UserDefaults.standard.register(defaults: [NotificationsController.Key.notificationTime : 1000,
            NotificationsController.Key.hasPromptedForUserNotifications : false,
            NotificationsController.Key.notificationsEnabled: false,
            ReviewHelper.appLaunchCountMod3Key: 0])

        UNUserNotificationCenter.current().delegate = notificationDelegate

        // this will schedule notifications if they are allowed and enabled
        Current.notificationsController.scheduleNotifications()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            NSLog("AVAudioSession setCategory failed!")
        }
        
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        ReviewHelper.registerAppLaunch()        
    }
}
