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

class TodayViewController: UIViewController, NCWidgetProviding {
        
    @IBOutlet weak var photoView: UIImageView!
    @IBOutlet weak var yearLabel: UILabel!
    @IBOutlet weak var photoHeightConstraint: NSLayoutConstraint!
    
    var imageManager: PHCachingImageManager!
    var model: TodayViewModel?
    
    let photoViewHeight = CGFloat(200)
    let cacheSize = CGSizeMake(256, 256)
    let dateFormatter = NSDateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dateFormatter.dateFormat = "YYYY"
        yearLabel.text = "No Memories Today :("
        
#if (arch(i386) || arch(x86_64)) && os(iOS)
        let date = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!.dateWithEra(1, year: 2016, month: 8, day: 8, hour: 0, minute: 0, second: 0, nanosecond: 0)!
#else
        let date = NSDate()
#endif
        
        if PHPhotoLibrary.authorizationStatus() == .Authorized {
            model = TodayViewModel(date: date)
            imageManager = PHCachingImageManager()
            imageManager.startCachingImagesForAssets(model!.assets, targetSize: cacheSize, contentMode: .AspectFit, options: nil)
        }
        
        let imageTapper = UITapGestureRecognizer(target: self, action: "launchApp")
        photoView.addGestureRecognizer(imageTapper)
        photoView.userInteractionEnabled = true
    }

    override func viewDidAppear(animated: Bool) {
        guard let model = self.model else {
            return
        }

        let asset = model.randomAsset()
        displayAsset(asset)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func launchApp() {
        extensionContext?.openURL(NSURL(string: "memories://")!, completionHandler: nil)
    }
    
    @IBAction func nextBtnTapped(sender: UIButton) {
        guard let model = self.model else {
            return
        }
        
        let asset = model.nextAsset()
        displayAsset(asset)
    }
    
    @IBAction func previousBtnTapped(sender: UIButton) {
        guard let model = self.model else {
            return
        }
        
        let asset = model.previousAsset()
        displayAsset(asset)
    }
    
    private func displayAsset(asset: PHAsset?, completion: ((Bool) -> Void)? = nil) {
        guard let asset = asset else {
            hidePhotoView(true) {
                completion?(false)
            }
            return
        }
        
        imageManager.requestImageForAsset(asset, targetSize: cacheSize, contentMode: .AspectFill, options: nil, resultHandler: { (result, userInfo) -> Void in
            if let image = result, assetDate = asset.creationDate {
                self.hidePhotoView(false) {
                    self.photoView.image = image
                    self.yearLabel.text = self.dateFormatter.stringFromDate(assetDate)
                    
                    completion?(true)
                }
            }
            else {
                completion?(false)
            }
        })
    }

    private func hidePhotoView(hide: Bool, completion: (() -> Void)?) {
        let constant = hide ? 0 : photoViewHeight
        
        if photoHeightConstraint.constant != constant {
            photoHeightConstraint.constant = constant
            
            UIView.animateWithDuration(0.25, animations: {
                self.view.layoutIfNeeded()
            }) { Bool in
                completion?()
            }
        }
        else {
            completion?()
        }
    }
    
    // MARK: NCWidgetProviding
    
    func widgetMarginInsetsForProposedMarginInsets(defaultMarginInsets: UIEdgeInsets) -> (UIEdgeInsets) {
        return UIEdgeInsetsZero
    }
    
    func widgetPerformUpdateWithCompletionHandler(completionHandler: ((NCUpdateResult) -> Void)) {
        guard let model = self.model else {
            completionHandler(NCUpdateResult.Failed)
            return
        }
        
        let asset = model.randomAsset()
        displayAsset(asset) { Bool in
            completionHandler(NCUpdateResult.NewData)
        }
    }
    
}
