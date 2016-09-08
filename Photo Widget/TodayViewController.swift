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
    
    let expandedWidgetHeight = CGFloat(integerLiteral: 245)
    let photoViewExpandedHeight = CGFloat(integerLiteral: 200)
    let cacheSize = CGSize(width: 256, height: 256)
    let dateFormatter = DateFormatter()
    let requestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        return options
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOSApplicationExtension 10.0, *) {
            extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        }
        
        dateFormatter.dateFormat = "YYYY"
        yearLabel.text = "No Memories Today :("
        
#if (arch(i386) || arch(x86_64)) && os(iOS)
    let date = Calendar(identifier: Calendar.Identifier.gregorian).date(from: DateComponents(era: 1, year: 2016, month: 8, day: 8, hour: 0, minute: 0, second: 0, nanosecond: 0))!
#else
        let date = Date()
#endif
        
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            imageManager = PHCachingImageManager()
            model = TodayViewModel(date: date) { [weak self] in
                guard let `self` = self else { return }
                
                self.imageManager.startCachingImages(for: self.model!.assets, targetSize: self.cacheSize, contentMode: .aspectFill, options: self.requestOptions)
                if self.readyForDisplay && !self.assetDisplayed {
                    self.displayAsset(self.model!.currentAsset())
                }
            }
        }
        
        let imageTapper = UITapGestureRecognizer(target: self, action: #selector(TodayViewController.launchApp))
        photoView.addGestureRecognizer(imageTapper)
        photoView.isUserInteractionEnabled = true
    }

    override func viewDidAppear(_ animated: Bool) {
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
        extensionContext?.open(URL(string: "memories://")!, completionHandler: nil)
    }
    
    @IBAction func nextBtnTapped(_ sender: UIButton) {
        guard let model = self.model else {
            return
        }
        
        displayAsset(model.nextAsset())
    }
    
    @IBAction func previousBtnTapped(_ sender: UIButton) {
        guard let model = self.model else {
            return
        }
        
        displayAsset(model.previousAsset())
    }
    
    private func displayAsset(_ asset: PHAsset?, completion: ((Bool) -> Void)? = nil) {
        guard let asset = asset else {
            self.currentAsset = nil
            hidePhotoView(true) {
                completion?(false)
            }
            return
        }
        
        assetDisplayed = true
        imageManager.requestImage(for: asset, targetSize: cacheSize, contentMode: .aspectFill, options: requestOptions) { result, userInfo in
            if let image = result, let assetDate = asset.creationDate {
                self.hidePhotoView(false) {
                    let imageWider = image.size.width > self.photoView.image?.size.width ?? CGFloat.leastNormalMagnitude
                    let newAsset = asset != self.currentAsset
                    let newData = newAsset || imageWider
                    
                    if newData {
                        self.currentAsset = asset
                        self.photoView.image = image
                        self.yearLabel.text = self.dateFormatter.string(from: assetDate)
                    }
                    
                    completion?(newData)
                }
            }
            else {
                completion?(false)
            }
        }
    }

    private func hidePhotoView(_ hide: Bool, completion: ((Void) -> Void)?) {
        let constant: CGFloat
        if #available(iOSApplicationExtension 10.0, *) {
            constant = hide ? 0 : photoViewHeightFor(activeDisplayMode: extensionContext!.widgetActiveDisplayMode)
        } else {
            constant = hide ? 0 : photoViewExpandedHeight
        }
        
        setPhotoViewHeight(constant, completion: completion)
    }
    
    private func setPhotoViewHeight(_ height: CGFloat, completion: ((Void) -> Void)? = nil) {
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
    
    // MARK: NCWidgetProviding
    
    func widgetMarginInsets(forProposedMarginInsets defaultMarginInsets: UIEdgeInsets) -> UIEdgeInsets {
        return .zero
    }
    
    func widgetPerformUpdate(completionHandler: @escaping (NCUpdateResult) -> Swift.Void) {
        readyForDisplay = true

        guard let model = self.model else {
            completionHandler(NCUpdateResult.failed)
            return
        }
        
        displayAsset(model.currentAsset()) { newData in
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
