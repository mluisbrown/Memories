//
//  SettingsViewModel.swift
//  Memories
//
//  Created by Michael Brown on 14/09/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import Foundation

struct SettingsViewModel {
    let notificationsEnabled : Dynamic<Bool>
    let notificationHour : Dynamic<Int>
    let notificationMinute : Dynamic<Int>
    let sourcePhotoLibrary: Dynamic<Bool>
    let sourceICloudShare: Dynamic<Bool>
    let sourceITunes: Dynamic<Bool>
    let userHasUpgraded : Dynamic<Bool>
    let upgradeButtonText : Dynamic<String>
    let storeAvailable : Dynamic<Bool>
    
    init(notificationsEnabled: Bool, notificationHour: Int, notificationMinute: Int,
         sourcePhotoLibrary: Bool, sourceICloudShare: Bool, sourceITunes: Bool) {
        self.notificationsEnabled = Dynamic(notificationsEnabled)
        self.notificationHour = Dynamic(notificationHour)
        self.notificationMinute = Dynamic(notificationMinute)
        self.userHasUpgraded = Dynamic(UpgradeManager.upgraded)
        self.sourcePhotoLibrary = Dynamic(sourcePhotoLibrary)
        self.sourceICloudShare = Dynamic(sourceICloudShare)
        self.sourceITunes = Dynamic(sourceITunes)
        
        let buy = NSLocalizedString("Buy", comment: "")
        self.upgradeButtonText = Dynamic(buy)
        self.storeAvailable = Dynamic(UpgradeManager.upgradePrice != nil)
        
        UpgradeManager.getUpgradePrice { (price) in
            if let price = price {
                self.upgradeButtonText.value = buy + " " + price
                self.storeAvailable.value = true
            }
        }
    }
}