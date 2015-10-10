//
//  PhotoViewController.swift
//  Memories
//
//  Created by Michael Brown on 08/07/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit
import Photos

class PhotoViewController: UIViewController, UIScrollViewDelegate {
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet weak var shareButton: UIButton!

    let PADDING : CGFloat = 10.0;
    
    var upgradePromptShown = false
    var initialOffsetSet = false
    var initialPage : Int!
    var model : PhotoViewModel!
    var pageViews: [ZoomingPhotoView?] = []
    let imageManager : PHCachingImageManager
    var cacheSize : CGSize = CGSizeZero
    
    required init?(coder aDecoder: NSCoder) {
        self.imageManager = PHCachingImageManager()
        super.init(coder: aDecoder)
    }
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initialPage = model.selectedAsset
        // TODO: find out optimum size to use
        cacheSize = CGSizeMake(256, 256)
        print("cacheSize: \(cacheSize)")
        imageManager.startCachingImagesForAssets(model.assets, targetSize: cacheSize, contentMode: .AspectFill, options: nil)
        
        let pageCount = model.assets.count
        for _ in 0..<pageCount {
            pageViews.append(nil)
        }
    }

    override func viewDidLayoutSubviews() {
        let pageCount = model.assets.count
        
        let pagesScrollViewSize = scrollView.bounds.size
        scrollView.contentSize = CGSize(width: pagesScrollViewSize.width * CGFloat(pageCount),
            height: pagesScrollViewSize.height)
        
        self.loadVisiblePages()
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        self.initialPage = self.model.selectedAsset
        self.initialOffsetSet = false
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: Actions
    @IBAction func sharePhoto(sender: UIButton) {
        let page = model.selectedAsset
        
        if let pageView = pageViews[page] where !pageView.imageIsDegraded {
            let avc = UIActivityViewController(activityItems: [pageView.image!], applicationActivities: nil)
            if let popover = avc.popoverPresentationController {
                popover.sourceView = sender
                popover.sourceRect = sender.bounds
                popover.permittedArrowDirections = .Down
            }
            
            presentViewController(avc, animated: true, completion: nil)
        }
    }
    
    // MARK: Internal implementation
    func loadPage(page: Int, requestFullImage: Bool) {
        guard page >= 0 && page < model.assets.count else {
            return
        }

        // setup the frame for the view
        let bounds = scrollView.bounds
        var frame = bounds
        frame.size.width -= (2.0 * PADDING);
        frame.origin.x = bounds.size.width * CGFloat(page) + PADDING
        frame.origin.y = 0.0

        // if we already have a view with a full image or
        // if we don't need the full image
        // make sure it's layed out correctly
        if let pageView = pageViews[page] {
            if !requestFullImage || !pageView.imageIsDegraded {
                pageView.frame = frame;
                pageView.adjustZoomScale();
                if requestFullImage {
                    shareButton.enabled = true
                }
                return
            }
        }

        let pageView : ZoomingPhotoView!
        
        if pageViews[page] != nil {
            pageView = pageViews[page]
        } else {
            pageView = ZoomingPhotoView()
            scrollView.addSubview(pageView)
            pageViews[page] = pageView
        }
        pageView.frame = frame

        let asset = model.assets[page]

        // always get a thumbnail first
        pageView.imageIsDegraded = true
        imageManager.requestImageForAsset(asset, targetSize: cacheSize, contentMode: .AspectFill, options: nil, resultHandler: { (result, userInfo) -> Void in
            if let image = result {
                NSLog("Cache Result with image for page \(page) requestFullImage: \(requestFullImage) iamgeSize: \(image.size.width), \(image.size.height)");
                pageView.image = result
                if page == self.model.selectedAsset {
                    self.shareButton.enabled = false
                }
            }
        })
        
        // then get the full size image if required
        if requestFullImage {
            if !UpgradeManager.highQualityViewAllowed() {
                guard !UpgradeManager.upgradePromptShown else {
                    pageView.hideProgressView(true)
                    return
                }
                
                UpgradeManager.promptForUpgradeInViewController(self) {
                    if !$0 {
                        pageView.hideProgressView(true)
                    } else {
                        self.loadHighQualityImageForAsset(asset, page: page)
                    }
                }
                
                return
            }
            
            loadHighQualityImageForAsset(asset, page: page)
        }
    }
    
    func loadHighQualityImageForAsset(asset: PHAsset, page: Int) {
        let options = PHImageRequestOptions()
        let pageView = pageViews[page]!
        
        options.progressHandler  = {(progress : Double, error: NSError?, stop: UnsafeMutablePointer<ObjCBool>, userInfo: [NSObject : AnyObject]?) -> Void in
            NSLog("Progress: %f", progress);
            dispatch_async(dispatch_get_main_queue()) {
                pageView.updateProgress(progress)
                
                if error != nil {
                    pageView.fullImageUnavailable = true
                }
            }
        }
        
        options.networkAccessAllowed = true
        options.deliveryMode = .HighQualityFormat
        options.synchronous = false
        
        let requestId = PHImageManager.defaultManager().requestImageForAsset(asset, targetSize: PHImageManagerMaximumSize, contentMode: .AspectFit, options: options) { (result, userInfo) -> Void in
            if let image = result {
                NSLog("Result with image for page \(page) requestFullImage: true iamgeSize: \(image.size.width), \(image.size.height)");
                UpgradeManager.highQualityViewCount++
                pageView.image = image
                pageView.imageIsDegraded = false
                if page == self.model.selectedAsset {
                    self.shareButton.enabled = true
                }
            }
            
            if let error = userInfo?[PHImageErrorKey] as? NSError {
                pageView.fullImageUnavailable = true
                NSLog("Error: \(error.localizedDescription)")
            }
        }
        
        pageView.imageRequestId = requestId
    }
    
    func purgePage(page: Int) {
        guard page >= 0 && page < pageViews.count else {
            return
        }
        
        // Remove a page from the scroll view and reset the container array
        if let pageView = pageViews[page] {
            if let requestId = pageView.imageRequestId {
                PHImageManager.defaultManager().cancelImageRequest(requestId)
            }
            pageView.image = nil
            pageView.removeFromSuperview()
            pageViews[page] = nil
        }
    }
    
    func loadVisiblePages() {
        let initialLoad = !initialOffsetSet
        
        if (!initialOffsetSet) {
            scrollView.contentOffset = contentOffsetForPageAtIndex(initialPage)
            initialOffsetSet = true
        }
        
        // First, determine which page is currently visible
        let pageWidth = scrollView.bounds.size.width
        let fractionalPage = scrollView.contentOffset.x / pageWidth;
        let page = lround(Double(fractionalPage))
        
        if !initialLoad &&
            page == model.selectedAsset {
            return
        }
        
        NSLog("Visible page: %d", page);
        model.selectedAsset = page
        
        // Work out which pages you want to load
        let firstPage = page - 1
        let lastPage = page + 1
        
        // Purge anything before the first page
        for var index = 0; index < firstPage; ++index {
            purgePage(index)
        }
        
        // Load pages in our range
        for index in firstPage...lastPage {
            loadPage(index, requestFullImage: index == page)
        }
        
        // Purge anything after the last page
        for var index = lastPage+1; index < model.assets.count; ++index {
            purgePage(index)
        }
    }
    
    func purgeAllViews() {
        for (idx, _) in pageViews.enumerate() {
            purgePage(idx)
        }
    }
    
    func contentOffsetForPageAtIndex(index : Int) -> CGPoint {
        let pageWidth = scrollView.bounds.size.width;
        let newOffset = CGFloat(index) * pageWidth;
        return CGPointMake(newOffset, 0);
    }
    
    // MARK: UIScrollViewDelegate
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        if scrollView == self.scrollView {
            loadVisiblePages()
        }
    }
}
