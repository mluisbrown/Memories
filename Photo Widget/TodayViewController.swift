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
    var currentAsset: PHAsset?
    var readyForDisplay = false
    var assetDisplayed = false
    
    let photoViewHeight = CGFloat(integerLiteral: 200)
    let cacheSize = CGSize(width: 256, height: 256)
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
            imageManager = PHCachingImageManager()
            model = TodayViewModel(date: date) { [unowned self] in
                self.imageManager.startCachingImagesForAssets(self.model!.assets, targetSize: self.cacheSize, contentMode: .AspectFill, options: nil)
                if self.readyForDisplay && !self.assetDisplayed {
                    self.displayAsset(self.model!.currentAsset())
                }
            }
        }
        
        let imageTapper = UITapGestureRecognizer(target: self, action: #selector(TodayViewController.launchApp))
        photoView.addGestureRecognizer(imageTapper)
        photoView.userInteractionEnabled = true
    }

    override func viewDidAppear(animated: Bool) {
        readyForDisplay = true
        guard let model = self.model else {
            return
        }
        
        displayAsset(model.currentAsset())
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
        
        displayAsset(model.nextAsset())
    }
    
    @IBAction func previousBtnTapped(sender: UIButton) {
        guard let model = self.model else {
            return
        }
        
        displayAsset(model.previousAsset())
    }
    
    private func displayAsset(asset: PHAsset?, completion: (Bool -> Void)? = nil) {
        guard let asset = asset else {
            self.currentAsset = nil
            hidePhotoView(true) {
                completion?(false)
            }
            return
        }
        
        assetDisplayed = true
        
        let options = PHImageRequestOptions()
        options.networkAccessAllowed = false
        options.deliveryMode = .Opportunistic
        options.synchronous = false
        
        imageManager.requestImageForAsset(asset, targetSize: cacheSize, contentMode: .AspectFill, options: nil) { (result, userInfo) -> Void in
            if let image = result, assetDate = asset.creationDate {
                self.hidePhotoView(false) {
                    let newImageWider = image.size.width > self.photoView.image?.size.width
                    let newAsset = asset != self.currentAsset
                    let newData = newAsset || newImageWider
                    
                    if newData {
                        self.currentAsset = asset
                        self.photoView.image = image
                        self.yearLabel.text = self.dateFormatter.stringFromDate(assetDate)
                    }
                    
                    completion?(newData)
                }
            }
            else {
                completion?(false)
            }
        }
    }

    private func hidePhotoView(hide: Bool, completion: (Void -> Void)?) {
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
    
    func widgetMarginInsetsForProposedMarginInsets(defaultMarginInsets: UIEdgeInsets) -> UIEdgeInsets {
        return UIEdgeInsetsZero
    }
    
    func widgetPerformUpdateWithCompletionHandler(completionHandler: NCUpdateResult -> Void) {
        readyForDisplay = true

        guard let model = self.model else {
            completionHandler(NCUpdateResult.Failed)
            return
        }
        
        displayAsset(model.currentAsset()) { newData in
            if newData {
                completionHandler(NCUpdateResult.NewData)
            }
            else {
                completionHandler(NCUpdateResult.NoData)
            }
        }
    }
    
}
