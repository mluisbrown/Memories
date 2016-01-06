//
//  DatePickerViewController.swift
//  Memories
//
//  Created by Michael Brown on 23/11/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit
import Photos
import DACircularProgress
import Cartography

class DatePickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    @IBOutlet weak var datePicker: UIPickerView!
    @IBOutlet weak var goButton: UIButton!
    @IBOutlet weak var todayButton: UIButton!

    var newDateSelected = false
    var initialDate: NSDate?
    var selectedDate: NSDate?
    var datesWithCount: [(date: NSDate, count: Int)] = []
    
    let progressView = DACircularProgressView()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        goButton.layer.borderWidth = 1
        goButton.layer.borderColor = UIColor.whiteColor().CGColor
        goButton.layer.cornerRadius = 4
        todayButton.layer.borderWidth = 1
        todayButton.layer.borderColor = UIColor.whiteColor().CGColor
        todayButton.layer.cornerRadius = 4
        
        progressView.trackTintColor = UIColor.clearColor()
        progressView.thicknessRatio = 0.1
        view.addSubview(progressView)
        
        constrain(view, progressView) {view, progressView in
            progressView.width == 40
            progressView.height == 40
            progressView.center == view.center
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        DatePickerViewController.buildDatesWithCount(progressView) {
            self.datesWithCount = $0
            self.progressView.hidden = true
            self.datePicker.reloadAllComponents()
            
            if let initialDate = self.initialDate {
                if let initialRow = self.getInitialRow(initialDate) {
                    self.datePicker.selectRow(initialRow, inComponent: 0, animated: false)
                }
            }
        }
    }
    
// MARK: UIPickerViewDataSource
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return datesWithCount.count;
    }
    
// MARK: UIPickerViewDelegate
    
    func pickerView(pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusingView view: UIView?) -> UIView {
        var pickerRowView = view as! DatePickerRowView!
        if view == nil {
            pickerRowView = DatePickerRowView()
        }

        pickerRowView.setData(datesWithCount[row].date, count: datesWithCount[row].count)
        return pickerRowView
    }
    
// Actions
    @IBAction func selectDateAndClose(sender: UIButton) {
        selectedDate = datesWithCount[datePicker.selectedRowInComponent(0)].date

        if let ppc = self.popoverPresentationController {
            presentingViewController?.dismissViewControllerAnimated(true) {
                if let ppcDelegate = ppc.delegate {
                    ppcDelegate.popoverPresentationControllerDidDismissPopover?(ppc)
                }
            }
        }
    }

    @IBAction func gotoToday(sender: UIButton) {
        if let todayRow = self.getInitialRow(NSDate()) {
            self.datePicker.selectRow(todayRow, inComponent: 0, animated: true)
        }
    }
    
    
// MARK: helpers
    private func getInitialRow(initialDate : NSDate) -> Int? {
        let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
        let initialDay = gregorian.ordinalityOfUnit(.Day, inUnit: .Era, forDate: initialDate)
        
        let diffs: [Int] = datesWithCount.map() {
            let countDay = gregorian.ordinalityOfUnit(.Day, inUnit: .Era, forDate: $0.date)
            return abs(countDay - initialDay)
        }

        // get the index of the smallest date difference (ie, the closest matching date)
        return zip(diffs, diffs.indices).minElement { $0.0 < $1.0 }.map { $0.1 }
    }
    
    private static func buildDatesWithCount(progressView: DACircularProgressView, completion: (datesWithCount: [(date: NSDate, count: Int)]) -> ()) {
        var datesMap = [NSDate : Int]()
        
        // don't want to trigger a "Allow Photos?"
        guard PHPhotoLibrary.authorizationStatus() == .Authorized else {
            completion(datesWithCount: [])
            return
        }
        
        let queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)
        
        dispatch_async(queue) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            if #available(iOS 9.0, *) {
                options.includeAssetSourceTypes = [.TypeUserLibrary, .TypeiTunesSynced, .TypeCloudShared]
            }
            let fetchResult = PHAsset.fetchAssetsWithMediaType(.Image, options: options)
            
            let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
            let todayComps = gregorian.components([.Year, .Month, .Day], fromDate: NSDate())
            let currentYear = todayComps.year
            
            let fetchCount = fetchResult.count
            let mainQueue = dispatch_get_main_queue()
            var steppedProgress = CGFloat(0.04)
            fetchResult.enumerateObjectsUsingBlock { (object, index, stop) -> Void in
                let progress = CGFloat(index) / CGFloat(fetchCount)
                if progress > steppedProgress {
                    dispatch_async(mainQueue) {
                        progressView.setProgress(progress, animated: false)
                    }
                    steppedProgress += 0.04
                }
                
                let asset : PHAsset = object as! PHAsset
                let comps = gregorian.components([.Month, .Day], fromDate: asset.creationDate!)
                let date = gregorian.dateWithEra(1, year: currentYear, month: comps.month, day: comps.day, hour: 0, minute: 0, second: 0, nanosecond: 0)!
                
                if let entry = datesMap[date] {
                    datesMap[date] = entry + 1
                } else {
                    datesMap[date] = 1
                }
            }

            dispatch_async(mainQueue) {
                progressView.setProgress(1, animated: false)
                completion(datesWithCount: datesMap.map {
                    (date: $0.0, count: $0.1)
                }.sort {
                    $0.date.compare($1.date) == .OrderedAscending
                })
            }
        }
    }
}
