//
//  TodayViewController.swift
//  Photo Widget
//
//  Created by Michael Brown on 06/01/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import UIKit
import NotificationCenter
import Photos
import ReactiveSwift
import ReactiveCocoa
import Result

class TodayViewController: UIViewController {
        
    @IBOutlet weak var photoView: UIImageView!
    @IBOutlet weak var yearLabel: UILabel!
    @IBOutlet weak var photoHeightConstraint: NSLayoutConstraint!
    
    private var model: TodayViewModel?
    
    private let expandedWidgetHeight = CGFloat(245)
    private let photoViewExpandedHeight = CGFloat(200)

    private var readyForDisplay: Signal<(), NoError>? = nil
    
    private func createAndBindToModel(for date: Date) {
        model = TodayViewModel(date: date)
        
        yearLabel.reactive.text <~ model!.yearText.producer
        
        model?.currentImage.producer
            .observe(on: UIScheduler())
            .startWithValues {
                self.display(image: $0)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOSApplicationExtension 10.0, *) {
            extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        }
        
        yearLabel.text = "No Memories Today :("
        
#if (arch(i386) || arch(x86_64)) && os(iOS)
        let date = Calendar(identifier: Calendar.Identifier.gregorian).date(from: DateComponents(era: 1, year: 2016, month: 8, day: 8, hour: 0, minute: 0, second: 0, nanosecond: 0))!
#else
        let date = Date()
#endif
        
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            self.createAndBindToModel(for: date)
        }
        
        let imageTapper = UITapGestureRecognizer(target: self, action: #selector(TodayViewController.launchApp))
        photoView.addGestureRecognizer(imageTapper)
        photoView.isUserInteractionEnabled = true
    }

    @objc func launchApp() {
        extensionContext?.open(URL(string: "memories://")!)
    }
    
    @IBAction func nextBtnTapped(_ sender: UIButton) {
        model?.nextImage()
    }
    
    @IBAction func previousBtnTapped(_ sender: UIButton) {
        model?.previousImage()
    }
    
    private func display(image: UIImage?, completion: ((Bool) -> Void)? = nil) {
        showPhotoView(image != nil) {
            self.photoView.image = image
            completion?(true)
        }
    }

    private func showPhotoView(_ show: Bool, completion: (() -> Void)?) {
        let constant: CGFloat
        if #available(iOSApplicationExtension 10.0, *) {
            constant = show ? photoViewHeightFor(activeDisplayMode: extensionContext!.widgetActiveDisplayMode) : 0
        } else {
            constant = show ? photoViewExpandedHeight : 0
        }
        
        setPhotoViewHeight(constant, completion: completion)
    }
    
    private func setPhotoViewHeight(_ height: CGFloat, completion: (() -> Void)? = nil) {
        let showYearLabel = height == photoViewExpandedHeight || height == 0
        
        if photoHeightConstraint.constant != height {
            photoHeightConstraint.constant = height
            
            UIView.animate(withDuration: 0.25, animations: {
                self.view.layoutIfNeeded()
                self.yearLabel.alpha = showYearLabel ? 1.0 : 0.0
            }) { Bool in
                completion?()
            }
        }
        else {
            completion?()
        }
    }
    
    @available(iOSApplicationExtension 10.0, *)
    private func photoViewHeightFor(activeDisplayMode: NCWidgetDisplayMode) -> CGFloat {
        let photoViewHeight: CGFloat
        
        switch activeDisplayMode {
        case .compact:
            photoViewHeight = extensionContext!.widgetMaximumSize(for: activeDisplayMode).height
        case .expanded:
            photoViewHeight = photoViewExpandedHeight
        }
        
        return photoViewHeight
    }
}

// MARK: NCWidgetProviding
extension TodayViewController: NCWidgetProviding {
    func widgetMarginInsets(forProposedMarginInsets defaultMarginInsets: UIEdgeInsets) -> UIEdgeInsets {
        return .zero
    }
    
    func widgetPerformUpdate(completionHandler: @escaping (NCUpdateResult) -> Swift.Void) {
        guard let model = self.model else {
            completionHandler(NCUpdateResult.failed)
            return
        }
        
        display(image: model.currentImage.value) { newData in
            if newData {
                completionHandler(NCUpdateResult.newData)
            }
            else {
                completionHandler(NCUpdateResult.noData)
            }
        }
    }
    
    @available(iOSApplicationExtension 10.0, *)
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        
        switch activeDisplayMode {
        case .compact:
            preferredContentSize = maxSize
        case .expanded:
            preferredContentSize = CGSize(width: maxSize.width, height: expandedWidgetHeight)
        }
        
        let showingPhoto = photoHeightConstraint.constant != 0
        let height = showingPhoto ? photoViewHeightFor(activeDisplayMode: activeDisplayMode) : 0
        setPhotoViewHeight(height)
    }
}
