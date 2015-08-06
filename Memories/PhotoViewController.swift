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

    let PADDING : CGFloat = 10.0;
    
    var initialOffsetSet = false
    var initialPage : Int!
    var model : PhotoViewModel!
    var pageViews: [ZoomingPhotoView?] = []
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initialPage = model.selectedAsset
        
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
        
        loadVisiblePages(false)
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        self.initialPage = self.model.selectedAsset
        self.initialOffsetSet = false
        
        coordinator.animateAlongsideTransition({ (context : UIViewControllerTransitionCoordinatorContext) -> Void in
            self.loadVisiblePages(true)
        }) { (context: UIViewControllerTransitionCoordinatorContext) -> Void in
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: Internal implementation
    func loadPage(page: Int) {
        guard page >= 0 && page < model.assets.count else {
            return
        }

        // setup the frame for the view
        let bounds = scrollView.bounds
        var frame = bounds
        frame.size.width -= (2.0 * PADDING);
        frame.origin.x = bounds.size.width * CGFloat(page) + PADDING
        frame.origin.y = 0.0

        // if we already have a view, make sure it's layed out correctly
        if let pageView = pageViews[page] {
            pageView.frame = frame;
            pageView.adjustZoomScale();

            return
        }
        
        let newPageView = ZoomingPhotoView()
        newPageView.frame = frame
        scrollView.addSubview(newPageView)

        let asset = model.assets[page]
        
        let targetSize = CGSizeMake(CGFloat(asset.pixelWidth / 2), CGFloat(asset.pixelHeight / 2))
        
        let options = PHImageRequestOptions()
        options.networkAccessAllowed = true
        options.deliveryMode = .Opportunistic
        options.synchronous = false
        options.progressHandler = {(progress : Double, error: NSError?, stop: UnsafeMutablePointer<ObjCBool>, userInfo: [NSObject : AnyObject]?) -> Void in
            NSLog("Progress: %f", progress);
            dispatch_async(dispatch_get_main_queue()) {
                newPageView.updateProgress(progress)
            }
        }
        
        let requestId = PHImageManager.defaultManager().requestImageForAsset(asset, targetSize: targetSize, contentMode: .AspectFit, options: options) { (result, userInfo) -> Void in
            guard let image = result else {
                return
            }
            
            if let info = userInfo {
                let degraded = info[PHImageResultIsDegradedKey] as! NSNumber
                if degraded == true {
                    dispatch_async(dispatch_get_main_queue()) {
                        // make sure progress is not 0 so it's displayed
                        newPageView.updateProgress(0.01)
                    }
                }
            }
            
            NSLog("Result with image");
            newPageView.image = image
        }
        
        newPageView.imageRequestId = requestId
        pageViews[page] = newPageView
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
    
    func loadVisiblePages(force : Bool) {
        if (!initialOffsetSet) {
            scrollView.contentOffset = contentOffsetForPageAtIndex(initialPage)
            initialOffsetSet = true
        }
        
        // First, determine which page is currently visible
        let pageWidth = scrollView.bounds.size.width
        let fractionalPage = scrollView.contentOffset.x / pageWidth;
        let page = lround(Double(fractionalPage))
        
        if !force &&
            page == model.selectedAsset &&
            page < pageViews.count &&
            pageViews[page] != nil {
            return;
        }
        
        NSLog("Visible page: %d", page);
        
        // Work out which pages you want to load
        let firstPage = page - 1
        let lastPage = page + 1
        
        // Purge anything before the first page
        for var index = 0; index < firstPage; ++index {
            purgePage(index)
        }
        
        // Load pages in our range
        for index in firstPage...lastPage {
            loadPage(index)
        }
        
        // Purge anything after the last page
        for var index = lastPage+1; index < model.assets.count; ++index {
            purgePage(index)
        }

        model.selectedAsset = page
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
            loadVisiblePages(false)
        }
    }
}
