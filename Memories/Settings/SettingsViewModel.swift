//
//  Settingsswift
//  Memories
//
//  Created by Michael Brown on 14/09/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import PHAssetHelper
import Photos

struct SettingsViewModel {
    let assetHelper = PHAssetHelper()

    let notificationsEnabled = MutableProperty<Bool>(false)
    let notificationTime = MutableProperty(Current.notificationsController.notificationTime())
    let sourceIncludeCurrentYear: MutableProperty<Bool>
    let sourcePhotoLibrary: MutableProperty<Bool>
    let sourceICloudShare: MutableProperty<Bool>
    let sourceITunes: MutableProperty<Bool>
    
    init() {
        let sources = assetHelper.assetSourceTypes

        self.sourceIncludeCurrentYear = MutableProperty(assetHelper.includeCurrentYear)
        self.sourcePhotoLibrary = MutableProperty(sources.contains(.typeUserLibrary))
        self.sourceICloudShare = MutableProperty(sources.contains(.typeCloudShared))
        self.sourceITunes = MutableProperty(sources.contains(.typeiTunesSynced))

        Current.notificationsController.notificationsAllowed()
            .map { $0 && Current.notificationsController.notificationsEnabled() }
            .startWithValues { [notificationsEnabled] enabled in
                notificationsEnabled.swap(enabled)
            }
    }

    func commit() {
        // schedule or disable notifications
        if notificationsEnabled.value {
            Current.notificationsController.setNotificationTime(notificationTime.value.hour, notificationTime.value.minute)
            Current.notificationsController.scheduleNotifications()
        } else {
            Current.notificationsController.disableNotifications()
        }
        
        // save the chosen source types
        var sources = PHAssetSourceType(rawValue: 0)
        
        if sourcePhotoLibrary.value { _ = sources.insert(.typeUserLibrary) }
        if sourceICloudShare.value { _ = sources.insert(.typeCloudShared) }
        if sourceITunes.value { _ = sources.insert(.typeiTunesSynced) }
        
        let includeCurrentYear = sourceIncludeCurrentYear.value
        if sources != assetHelper.assetSourceTypes ||
            includeCurrentYear != assetHelper.includeCurrentYear {
            assetHelper.assetSourceTypes = sources
            assetHelper.includeCurrentYear = includeCurrentYear
            assetHelper.refreshDatesMapCache()
            NotificationCenter.default.post(name: Notification.Name(rawValue: PHAssetHelper.sourceTypesChangedNotification), object: self)
        }
    }
}
