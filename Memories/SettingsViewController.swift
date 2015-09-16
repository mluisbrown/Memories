//
//  SettingsViewController.swift
//  Memories
//
//  Created by Michael Brown on 10/09/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {

    @IBOutlet weak var notificationsSwitch: UISwitch!
    @IBOutlet weak var timePicker: UIDatePicker!
    
    var viewModel : SettingsViewModel {
        didSet {
            viewModel.notificationsEnabled.bindAndFire {
                [unowned self] in
                self.notificationsSwitch.on = $0
                if $0 {
                    NotificationManager.enableNotifications()
                    self.timePicker.userInteractionEnabled = true
                    self.timePicker.alpha = 1
                } else {
                    NotificationManager.disableNotifications()
                    self.timePicker.userInteractionEnabled = false
                    self.timePicker.alpha = 0.5
                }
            }
            
            viewModel.notificationHour.bindAndFire {
                [unowned self] in
                let hour = $0
                let minute = self.viewModel.notificationMinute.value
                self.timePicker.date = self.timePicker.calendar.dateWithEra(1, year: 1970, month: 1, day: 1, hour: hour, minute: minute, second: 0, nanosecond: 0)!
            }

            viewModel.notificationMinute.bindAndFire {
                [unowned self] in
                let hour = self.viewModel.notificationHour.value
                let minute = $0
                self.timePicker.date = self.timePicker.calendar.dateWithEra(1, year: 1970, month: 1, day: 1, hour: hour, minute: minute, second: 0, nanosecond: 0)!
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.viewModel = SettingsViewModel(notificationsEnabled: false, notificationHour: 10, notificationMinute: 0)
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let notificationTime = NotificationManager.notificationTime()
        let notificationsEnabled = NotificationManager.notificationsEnabled() && NotificationManager.notificationsAllowed()
        viewModel = SettingsViewModel(notificationsEnabled: notificationsEnabled, notificationHour: notificationTime.hour, notificationMinute: notificationTime.minute)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // this is called when the settings view is dismissed via the Done button
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // schedule or disable notifications
        if viewModel.notificationsEnabled.value {
            NotificationManager.setNotificationTime(viewModel.notificationHour.value, viewModel.notificationMinute.value)
            NotificationManager.scheduleNotifications()
        } else {
            NotificationManager.disableNotifications()
        }
    }
    
    // MARK: Actions
    
    @IBAction func notificationSwitchValueChanged(sender: UISwitch) {
        viewModel.notificationsEnabled.value = sender.on
    }
    
    @IBAction func timePickerValueChanged(sender: UIDatePicker) {
        let hour = sender.calendar.component(.Hour, fromDate: timePicker.date)
        let minute = sender.calendar.component(.Minute, fromDate: timePicker.date)

        // read both values from the control first, then set the model values
        viewModel.notificationHour.value = hour
        viewModel.notificationMinute.value = minute
    }
}
