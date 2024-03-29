//
//  AppDelegate.swift
//  Memories
//
//  Created by Michael Brown on 18/06/2015.
//  Copyright (c) 2015 Michael Brown. All rights reserved.
//

import UIKit
import AVFoundation
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var notificationDelegate = NotificationCenterDelegate()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
        UserDefaults.standard.register(
            defaults: [
                NotificationsController.Key.notificationTime : 1000,
                NotificationsController.Key.hasPromptedForUserNotifications : false,
                NotificationsController.Key.notificationsEnabled: false,
                ReviewHelper.appLaunchCountMod3Key: 0,
                AppearanceViewModel.appearanceKey: "dark"
            ]
        )

        UNUserNotificationCenter.current().delegate = notificationDelegate

        // this will schedule notifications if they are allowed and enabled
        Current.notificationsController.scheduleNotifications()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            NSLog("AVAudioSession setCategory failed!")
        }

        window = UIWindow(frame: UIScreen.main.bounds)
        Current.updateAppearance = self.udpateAppearance

        if let appearanceSetting = Current.userDefaults.string(forKey: AppearanceViewModel.appearanceKey),
            let appearance = Appearance(rawValue: appearanceSetting) {
            udpateAppearance(appearance)
        }

        self.window?.rootViewController = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "initial")
        self.window?.makeKeyAndVisible()

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        let dateFormatter = DateFormatter().with {
            $0.dateFormat = "yyyyMMdd"
            $0.timeZone = TimeZone(secondsFromGMT: 0)
        }

        let urlHost: String?
        if #available(iOS 16, *) {
            urlHost = url.host()
        } else {
            urlHost = url.host
        }

        if let dateString = urlHost,
           let date = dateFormatter.date(from: dateString) {
            Current.notificationsController.setLaunchDate(date)
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        ReviewHelper.registerAppLaunch()        
    }

    func udpateAppearance(_ appearance: Appearance) {
        switch appearance {
        case .dark:
            window?.overrideUserInterfaceStyle = .dark
        case .light:
            window?.overrideUserInterfaceStyle = .light
        case .system:
            window?.overrideUserInterfaceStyle = .unspecified
        }
    }
}
