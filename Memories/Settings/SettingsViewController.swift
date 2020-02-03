//
//  SettingsViewController.swift
//  Memories
//
//  Created by Michael Brown on 10/09/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit
import MessageUI
import ReactiveCocoa
import ReactiveSwift

class SettingsViewController: UITableViewController, MFMailComposeViewControllerDelegate {

    enum Section: Int {
        case notifications
        case imageSources
        case appearance
        case feedback
    }

    @IBOutlet weak var notificationsSwitch: UISwitch!
    @IBOutlet weak var timePicker: UIDatePicker!
    @IBOutlet weak var feedbackCell: UITableViewCell!
    @IBOutlet weak var rateCell: UITableViewCell!
    @IBOutlet weak var sourceIncludeCurrentYearSwitch: UISwitch!
    @IBOutlet weak var sourcePhotoLibrarySwitch: UISwitch!
    @IBOutlet weak var sourceICloudSharedSwitch: UISwitch!
    @IBOutlet weak var sourceITunesSwitch: UISwitch!

    let viewModel: SettingsViewModel
    
    required init?(coder aDecoder: NSCoder) {
        viewModel = SettingsViewModel()

        super.init(coder: aDecoder)
    }
    
    private func initUI() {
        notificationsSwitch.isOn = viewModel.notificationsEnabled.value
        timePicker.date = timePicker.calendar.date(
            from: DateComponents(
                era: 1,
                year: 1970,
                month: 1,
                day: 1,
                hour: viewModel.notificationTime.value.hour,
                minute: viewModel.notificationTime.value.minute,
                second: 0, nanosecond: 0
            )
        )!
        
        sourceIncludeCurrentYearSwitch.isOn = viewModel.sourceIncludeCurrentYear.value
        sourcePhotoLibrarySwitch.isOn = viewModel.sourcePhotoLibrary.value
        sourceICloudSharedSwitch.isOn = viewModel.sourceICloudShare.value
        sourceITunesSwitch.isOn = viewModel.sourceITunes.value
    }
    
    private func bindToModel() {
        viewModel.notificationsEnabled.producer
            .observe(on: UIScheduler())
            .startWithValues { [unowned self] in
            if $0 {
                Current.notificationsController.enableNotifications()
                self.timePicker.isUserInteractionEnabled = true
                self.timePicker.alpha = 1
            } else {
                Current.notificationsController.disableNotifications()
                self.timePicker.isUserInteractionEnabled = false
                self.timePicker.alpha = 0.5
            }
        }
    }
    
    private func bindControls() {
        viewModel.notificationsEnabled <~ notificationsSwitch.reactive.isOnValues
        viewModel.notificationTime <~ timePicker.reactive.dates.map {
            (hour: self.timePicker.calendar.component(.hour, from: $0),
             minute: self.timePicker.calendar.component(.minute, from: $0))
        }
        
        viewModel.sourceIncludeCurrentYear <~ sourceIncludeCurrentYearSwitch.reactive.isOnValues
        viewModel.sourcePhotoLibrary <~ sourcePhotoLibrarySwitch.reactive.isOnValues
        viewModel.sourceICloudShare <~ sourceICloudSharedSwitch.reactive.isOnValues
        viewModel.sourceITunes <~ sourceITunesSwitch.reactive.isOnValues
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initUI()
        bindToModel()
        bindControls()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        viewModel.persist()
    }

    private func shouldHideSection(index: Int) -> Bool {
        if #available(iOS 13.0, *) {
            return false
        }

        return Section(rawValue: index) == .some(.appearance)
    }

    // MARK: UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        
        if cell == rateCell {
            rateApp()
        }
        else if cell == feedbackCell {
            sendFeedback()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let timePickerIndexPath = IndexPath(row: 1, section: 0)

        let height : CGFloat
        switch indexPath {
        case timePickerIndexPath:
            height = 162
        default:
            height = 44
        }
        
        return height
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return shouldHideSection(index: section) ? 0.1 : super.tableView(tableView, heightForHeaderInSection: section)
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return shouldHideSection(index: section) ? 0.1 : super.tableView(tableView, heightForFooterInSection: section)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return shouldHideSection(index: section) ? 0 : super.tableView(tableView, numberOfRowsInSection: section)
    }

    private func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            let composer = MFMailComposeViewController()
            composer.mailComposeDelegate = self;
            
            let device = UIDevice.current
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"]
            
            let body = "<div><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><hr><center>Developer Support Information</center><ul><li>Device Version: \(device.systemVersion)</li><li>Device Type: \(device.modelName)</li><li>App Version: \(appVersion!), Build: \(appBuild!)</li></ul><hr></div>"
            composer.setToRecipients(["memories@michael-brown.net"]);
            composer.setSubject("Memories Feedback")
            composer.setMessageBody(body, isHTML: true);
            
            self.present(composer, animated: true, completion: nil)
        } else {
            let title = NSLocalizedString("No e-mail account configured", comment: "No e-mail account configured") + "\nContact: memories@michael-brown.net"

            let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func rateApp() {
        let appId = 1037130497
        let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id\(appId)?action=write-review")!

        if UIApplication.shared.canOpenURL(appStoreURL) {
            UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
        }
    }
    
    // MARK: MFMailComposeViewControllerDelegate

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }    
}
