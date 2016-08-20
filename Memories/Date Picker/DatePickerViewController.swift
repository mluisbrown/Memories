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
import PHAssetHelper

class DatePickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    @IBOutlet weak var datePicker: UIPickerView!
    @IBOutlet weak var goButton: UIButton!
    @IBOutlet weak var todayButton: UIButton!

    let gregorian = Date.gregorianCalendar
    
    var newDateSelected = false
    var initialDate: Date?
    var selectedDate: Date?
    var datesWithCount: [(date: Date, count: Int)] = []
    
    let progressView = DACircularProgressView()
    let assetHelper = PHAssetHelper()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        goButton.layer.borderWidth = 1
        goButton.layer.borderColor = UIColor.white.cgColor
        goButton.layer.cornerRadius = 4
        todayButton.layer.borderWidth = 1
        todayButton.layer.borderColor = UIColor.white.cgColor
        todayButton.layer.cornerRadius = 4
        
        progressView.trackTintColor = UIColor.clear
        progressView.thicknessRatio = 0.1
        view.addSubview(progressView)
        
        constrain(view, progressView) {view, progressView in
            progressView.width == 40
            progressView.height == 40
            progressView.center == view.center
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.progressView.setProgress(0.33, animated: false)
        self.progressView.indeterminateDuration = 1
        self.progressView.indeterminate = 1
        
        self.buildDatesWithCount {
            self.datesWithCount = $0
            self.progressView.indeterminate = 0
            self.progressView.isHidden = true
            self.datePicker.reloadAllComponents()
            
            if let initialDate = self.initialDate {
                if let initialRow = self.getInitialRow(forDate: initialDate) {
                    self.datePicker.selectRow(initialRow, inComponent: 0, animated: false)
                }
            }
        }
    }
    
// MARK: UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return datesWithCount.count;
    }
    
// MARK: UIPickerViewDelegate
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        var pickerRowView = view as! DatePickerRowView!
        if view == nil {
            pickerRowView = DatePickerRowView()
        }

        pickerRowView?.setData(datesWithCount[row].date, count: datesWithCount[row].count)
        return pickerRowView!
    }
    
// Actions
    @IBAction func selectDateAndClose(_ sender: UIButton) {
        selectedDate = datesWithCount[datePicker.selectedRow(inComponent: 0)].date

        if let ppc = self.popoverPresentationController {
            presentingViewController?.dismiss(animated: true) {
                if let ppcDelegate = ppc.delegate {
                    ppcDelegate.popoverPresentationControllerDidDismissPopover?(ppc)
                }
            }
        }
    }

    @IBAction func gotoToday(_ sender: UIButton) {
        if let todayRow = self.getInitialRow(forDate: Date()) {
            self.datePicker.selectRow(todayRow, inComponent: 0, animated: true)
        }
    }
    
    
// MARK: helpers
    private func getInitialRow(forDate initialDate : Date) -> Int? {
        let initialDay = gregorian.ordinality(of: .day, in: .era, for: initialDate)
        
        let diffs: [Int] = datesWithCount.map() {
            let countDay = gregorian.ordinality(of: .day, in: .era, for: $0.date)
            return abs(countDay! - initialDay!)
        }

        // get the index of the smallest date difference (ie, the closest matching date)
        return zip(diffs, diffs.indices).min { $0.0 < $1.0 }.map { $0.1 }
    }
    
    private func buildDatesWithCount(withCompletion completion: @escaping (_ datesWithCount: [(date: Date, count: Int)]) -> ()) {
        var datesMap = [Date : Int]()
        
        // don't want to trigger a "Allow Photos?"
        guard PHPhotoLibrary.authorizationStatus() == .authorized else {
            completion([])
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            datesMap = self.assetHelper.datesMap()

            DispatchQueue.main.async {
                completion(datesMap.map {
                    (date: $0.0, count: $0.1)
                }.sorted {
                    $0.date.compare($1.date) == .orderedAscending
                })
            }
        }
    }
}
