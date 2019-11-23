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
import ReactiveSwift

class DatePickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    @IBOutlet weak var datePicker: UIPickerView!
    @IBOutlet weak var goButton: UIButton!
    @IBOutlet weak var todayButton: UIButton!

    private let gregorian = Date.gregorianCalendar
    
    var initialDate: Date?
    var selectedDate: Date?

    private let datesWithCount = MutableProperty([(date: Date, count: Int)]())
    
    private let progressView = DACircularProgressView()
    private let assetHelper = PHAssetHelper()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        goButton.layer.borderWidth = 1
        goButton.layer.cornerRadius = 4
        todayButton.layer.borderWidth = 1
        todayButton.layer.cornerRadius = 4

        adjustButtonBorderColor()

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
        progressView.setProgress(0.33, animated: false)
        progressView.indeterminateDuration = 1
        progressView.indeterminate = 1

        createBindings()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        adjustButtonBorderColor()
    }

    private func adjustButtonBorderColor() {
        let btnBorderColor: CGColor
        if #available(iOS 13.0, *) {
            btnBorderColor = UIColor.label.cgColor
        } else {
            btnBorderColor = UIColor.white.cgColor
        }

        goButton.layer.borderColor = btnBorderColor
        todayButton.layer.borderColor = btnBorderColor
    }

    private func createBindings() {
        datesWithCount.signal.observeValues { [weak self] _ in
            self?.progressView.indeterminate = 0
            self?.progressView.isHidden = true
            self?.datePicker.reloadAllComponents()
            
            if let initialDate = self?.initialDate,
                let initialRow = self?.getInitialRow(forDate: initialDate) {
                self?.datePicker.selectRow(initialRow, inComponent: 0, animated: false)
            }
        }
        
        datesWithCount <~ buildDatesWithCount().observe(on: UIScheduler())
    }
    
// MARK: - UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return datesWithCount.value.count;
    }
    
// MARK: - UIPickerViewDelegate
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let pickerRowView = view as? DatePickerRowView ?? DatePickerRowView()

        pickerRowView.setData(date: datesWithCount.value[row].date, count: datesWithCount.value[row].count)
        return pickerRowView
    }
    
// MARK: - Actions
    @IBAction func selectDateAndClose(_ sender: UIButton) {
        selectedDate = datesWithCount.value[datePicker.selectedRow(inComponent: 0)].date

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
    
    
// MARK: - Helpers
    private func getInitialRow(forDate initialDate : Date) -> Int? {
        let initialDay = gregorian.ordinality(of: .day, in: .era, for: initialDate)
        
        let diffs: [Int] = datesWithCount.value.map() {
            let countDay = gregorian.ordinality(of: .day, in: .era, for: $0.date)
            return abs(countDay! - initialDay!)
        }

        // get the index of the smallest date difference (ie, the closest matching date)
        return zip(diffs, diffs.indices).min { $0.0 < $1.0 }.map { $0.1 }
    }
    
    private func buildDatesWithCount() -> SignalProducer<[(date: Date, count: Int)], Never> {
        // don't want to trigger a "Allow Photos?"
        guard PHPhotoLibrary.authorizationStatus() == .authorized else {
            return SignalProducer<[(date: Date, count: Int)], Never>(value: [])
        }
        
        return SignalProducer<[(date: Date, count: Int)], Never> { observer, _ in
            observer.send(value: self.assetHelper.datesMap()
                .map { (date: $0.0, count: $0.1) }
                .sorted { $0.date.compare($1.date) == .orderedAscending })
            observer.sendCompleted()
        }
        .start(on: QueueScheduler(qos: .userInitiated))
    }
}
