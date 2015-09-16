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
    
    init(notificationsEnabled: Bool, notificationHour: Int, notificationMinute: Int) {
        self.notificationsEnabled = Dynamic(notificationsEnabled)
        self.notificationHour = Dynamic(notificationHour)
        self.notificationMinute = Dynamic(notificationMinute)
    }
}