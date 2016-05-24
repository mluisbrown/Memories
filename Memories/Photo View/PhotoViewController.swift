//
//  PhotoViewController.swift
//  Memories
//
//  Created by Michael Brown on 08/07/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit
import Photos

class PhotoViewController: UIViewController, UIScrollViewDelegate, UIViewControllerTransitioningDelegate, PHPhotoLibraryChangeObserver, ZoomingPhotoViewDelegate {
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var heartButton: UIButton!
    @IBOutlet weak var yearLabel: UILabel!

    let PADDING : CGFloat = 10.0;
    
    let heartFullImg = UIImage(named: "heart-full")!.imageWithRenderingMode(.AlwaysTemplate)
    let heartEmptyImg = UIImage(named: "heart-empty")!.imageWithRenderingMode(.AlwaysTemplate)
    
    var upgradePromptShown = false
    var initialOffsetSet = false
    var initialPage : Int!
    var model : PhotoViewModel!
    var pageViews: [ZoomingPhotoView?] = []
    let imageManager : PHCachingImageManager
    // If the size is too large then PhotoKit doesn't return an optimal image size
    // see rdar://25181601 (https://openradar.appspot.com/radar?id=6158824289337344)
    let cacheSize = CGSize(width: 256, height: 256)
    
    var hideStatusBar = false
    
    var presentTransition: PhotoViewPresentTransition?
    var dismissTransition: PhotoViewDismissTransition?
    
    required init?(coder aDecoder: NSCoder) {
        self.imageManager = PHCachingImageManager()
        super.init(coder: aDecoder)
    }
    
    deinit {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }

    var controlsHidden: Bool {
        get {
            return closeButton.alpha == 0
        }
    }
    
    private func buttonImageForFavorite(favorite: Bool) -> UIImage {
        return favorite ? heartFullImg : heartEmptyImg
    }
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initialPage = model.selectedIndex
        imageManager.startCachingImagesForAssets(model.assets, targetSize: cacheSize, contentMode: .AspectFill, options: nil)
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self);
    }

    override func viewDidAppear(animated: Bool) {
        hideStatusBar(true)
    }
    
    override func viewDidLayoutSubviews() {
        setupViews()
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        initialPage = model.selectedIndex
        initialOffsetSet = false
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return hideStatusBar || traitCollection.verticalSizeClass == .Compact
    }
    
    func hideStatusBar(hide: Bool) {
        hideStatusBar = hide
        UIView.animateWithDuration(0.25) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: Actions
    @IBAction func sharePhoto(sender: UIButton) {
        let page = model.selectedIndex
        
        let asset = model.assets[page]
        let options = PHImageRequestOptions()
        options.version = .Current
        options.networkAccessAllowed = false
        PHImageManager.defaultManager().requestImageDataForAsset(asset, options: options) {
            [weak self] imageData, dataUTI, orientation, info in
            guard let `self` = self else { return }

            if let imageData = imageData {
                let avc = UIActivityViewController(activityItems: [imageData], applicationActivities: nil)
                if let popover = avc.popoverPresentationController {
                    popover.sourceView = sender
                    popover.sourceRect = sender.bounds
                    popover.permittedArrowDirections = .Down
                }
                
                self.presentViewController(avc, animated: true, completion: nil)
            }
        }
    }
    
    @IBAction func deletePhoto(sender: UIButton) {
        let asset = model.selectedAsset
        
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({
            PHAssetChangeRequest.deleteAssets([asset])
        }, completionHandler: nil)
    }
    
    @IBAction func toggleFavorite(sender: UIButton) {
        let asset = model.selectedAsset
        let newState = !asset.favorite
        
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({
            let request = PHAssetChangeRequest(forAsset: asset)
            request.favorite = newState
        }, completionHandler: nil)
    }
    
    @IBAction func close(sender: UIButton) {
        if let navController = presentingViewController as? UINavigationController,
            gridViewController = navController.topViewController as? GridViewController {
            cancelAllImageRequests()
            PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)

            gridViewController.setSelectedIndex(model.selectedIndex)
            if traitCollection.verticalSizeClass == .Regular {
                hideStatusBar(false)
            }
            let imageView = gridViewController.imageViewForIndex(model.selectedIndex)
            let pageView = pageViews[model.selectedIndex]
            dismissTransition = PhotoViewDismissTransition(destImageView: imageView!, sourceImageView: pageView!.imageView)

            navController.dismissViewControllerAnimated(true) { self.purgeAllViews() }
        }
    }
    
    // MARK: Internal implementation
    func setupViews() {
        let pageCount = model.assets.count

        if pageViews.count == 0 {
            for _ in 0..<pageCount {
                pageViews.append(nil)
            }
            initialPage = model.selectedIndex
            initialOffsetSet = false
        }

        let pagesScrollViewSize = scrollView.bounds.size
        scrollView.contentSize = CGSize(width: pagesScrollViewSize.width * CGFloat(pageCount),
            height: pagesScrollViewSize.height)
        
        loadVisiblePages()
    }
    
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

        let asset = model.assets[page]
        if page == self.model.selectedIndex {
            heartButton.setImage(buttonImageForFavorite(asset.favorite), forState: .Normal)
            yearLabel.text = String("  \(asset.creationDate!.year)  ")
        }
        
        // if we already have a view with a full image or
        // if we don't need the full image
        // make sure it's layed out correctly
        if let pageView = pageViews[page] {
            if !requestFullImage || !pageView.imageIsDegraded {
                pageView.frame = frame
                if requestFullImage {
                    shareButton.enabled = true
                    deleteButton.enabled = true
                    heartButton.enabled = true
                }
                return
            }
        }

        let pageView : ZoomingPhotoView!
        
        if pageViews[page] != nil {
            pageView = pageViews[page]
        } else {
            pageView = ZoomingPhotoView()
            pageView.photoViewDelegate = self
            scrollView.addSubview(pageView)
            pageViews[page] = pageView
        }
        pageView.frame = frame

        // always get a thumbnail first
        pageView.imageIsDegraded = true
        imageManager.requestImageForAsset(asset, targetSize: cacheSize, contentMode: .AspectFill, options: nil, resultHandler: { (result, userInfo) -> Void in
            if let image = result {
                // NSLog("Cache Result with image for page \(page) requestFullImage: \(requestFullImage) iamgeSize: \(image.size.width), \(image.size.height)");
                pageView.image = image
                if page == self.model.selectedIndex {
                    self.shareButton.enabled = false
                    self.deleteButton.enabled = false
                    self.heartButton.enabled = false
                }
            }
        })
        
        // then get the full size image if required
        if requestFullImage {
            if !UpgradeManager.highQualityViewAllowed() {
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
        
        pageView.imageRequestId = PHImageManager.defaultManager().requestImageForAsset(asset, targetSize: PHImageManagerMaximumSize, contentMode: .AspectFit, options: options) { (result, userInfo) -> Void in
            if let image = result {
                UpgradeManager.highQualityViewCount += 1
                pageView.image = image
                pageView.imageIsDegraded = false
                if page == self.model.selectedIndex {
                    self.shareButton.enabled = true
                    self.heartButton.enabled = true

                    if #available(iOS 9.0, *) {
                        self.deleteButton.enabled = !asset.sourceType.contains(.TypeiTunesSynced)
                    } else {
                        self.deleteButton.enabled = true
                    }
                }
            }
            
            if let _ = userInfo?[PHImageErrorKey] as? NSError {
                pageView.fullImageUnavailable = true
            }
        }
    }
    
    func purgePage(page: Int) {
        guard page >= 0 && page < pageViews.count else {
            return
        }
        
        // Remove a page from the scroll view and reset the container array
        if let pageView = pageViews[page] {
            if let requestId = pageView.imageRequestId {
                PHImageManager.defaultManager().cancelImageRequest(requestId)
                pageView.imageRequestId = nil
            }
            pageView.image = nil
            pageView.removeFromSuperview()
            pageViews[page] = nil
        }
    }
    
    func cancelPageImageRequest(page: Int) {
        guard page >= 0 && page < pageViews.count else {
            return
        }
        
        if let pageView = pageViews[page] {
            if let requestId = pageView.imageRequestId {
                PHImageManager.defaultManager().cancelImageRequest(requestId)
                pageView.imageRequestId = nil
            }
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
            page == model.selectedIndex {
            return
        }
        
        model.selectedIndex = page
        
        // Work out which pages you want to load
        let firstPage = page - 1
        let lastPage = page + 1
        
        // Purge anything before the first page
        0.stride(to: firstPage, by: 1).forEach(purgePage)
        
        // Load pages in our range
        (firstPage...lastPage).forEach { loadPage($0, requestFullImage: $0 == page) }
        
        // Purge anything after the last page
        model.assets.count.stride(to: lastPage, by: -1).forEach(purgePage)
    }
    
    func cancelAllImageRequests() {
        pageViews.indices.forEach(cancelPageImageRequest)
    }
    
    func purgeAllViews() {
        pageViews.indices.forEach(purgePage)
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

    // MARK: UIViewControllerTransitioningDelegate
    func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return presentTransition
    }
    
    func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return dismissTransition
    }
    
    // MARK: PHPhotoLibraryChangeObserver
    
    func photoLibraryDidChange(changeInstance: PHChange) {
        dispatch_async(dispatch_get_main_queue()) {
            self.processLibraryChange(changeInstance)
        }
    }
    
    private func processLibraryChange(changeInstance: PHChange) {
        let newAssets:[PHAsset] = model.assets.flatMap {
            if let changeDetails = changeInstance.changeDetailsForObject($0) {
                return changeDetails.objectWasDeleted ? nil : changeDetails.objectAfterChanges as? PHAsset
            }
            else {
                return $0
            }
        }
        
        if newAssets.isEmpty {
            presentingViewController?.dismissViewControllerAnimated(true, completion: nil);
            return
        }
        
        let assetsDeleted = newAssets.count < model.assets.count
        let newSelectedAsset = min(model.selectedIndex, newAssets.count - 1)
        model = PhotoViewModel(assets: newAssets, selectedAsset: newSelectedAsset)
        
        if assetsDeleted {
            purgeAllViews()
            pageViews = []
            
            setupViews()
        }
        else {
            let asset = model.selectedAsset
            heartButton.setImage(buttonImageForFavorite(asset.favorite), forState: .Normal)
        }
    }
    
    // MARK: ZoomingPhotoViewDelegate
    func hideControls(hide: Bool) {
        guard hide != controlsHidden else {
            return
        }
        
        [shareButton, deleteButton, closeButton, heartButton, yearLabel].forEach {
            $0.alpha = hide ? 0 : 1
        }
    }
    
    func toggleControlsHidden() {
        hideControls(!controlsHidden)
    }
}
