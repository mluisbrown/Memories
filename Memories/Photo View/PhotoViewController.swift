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
    
    let heartFullImg = UIImage(named: "heart-full")!.withRenderingMode(.alwaysTemplate)
    let heartEmptyImg = UIImage(named: "heart-empty")!.withRenderingMode(.alwaysTemplate)
    
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
    var swipeDismissTransition: PhotoViewSwipeDismissTransition?
    
    required init?(coder aDecoder: NSCoder) {
        self.imageManager = PHCachingImageManager()
        super.init(coder: aDecoder)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    var controlsHidden: Bool {
        get {
            return closeButton.alpha == 0
        }
    }
    
    private func buttonImageForFavorite(_ favorite: Bool) -> UIImage {
        return favorite ? heartFullImg : heartEmptyImg
    }
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initialPage = model.selectedIndex
        imageManager.startCachingImages(for: model.assets, targetSize: cacheSize, contentMode: .aspectFill, options: nil)
        PHPhotoLibrary.shared().register(self);
        
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(PhotoViewController.viewDidPan))
        view.addGestureRecognizer(panRecognizer)
    }

    override func viewDidAppear(_ animated: Bool) {
        hideStatusBar(true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        self.cancelAllImageRequests()
        self.purgeAllViews()
    }
    
    override func viewDidLayoutSubviews() {
        setupViews()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        initialPage = model.selectedIndex
        initialOffsetSet = false
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .default
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return hideStatusBar || traitCollection.verticalSizeClass == .compact
    }
    
    func hideStatusBar(_ hide: Bool) {
        hideStatusBar = hide
        UIView.animate(withDuration: 0.25) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: Actions
    @IBAction func sharePhoto(_ sender: UIButton) {
        let page = model.selectedIndex
        
        let asset = model.assets[page]
        let options = PHImageRequestOptions()
        options.version = .current
        options.isNetworkAccessAllowed = false
        PHImageManager.default().requestImageData(for: asset, options: options) {
            [weak self] imageData, dataUTI, orientation, info in
            guard let `self` = self else { return }

            if let imageData = imageData {
                let avc = UIActivityViewController(activityItems: [imageData], applicationActivities: nil)
                if let popover = avc.popoverPresentationController {
                    popover.sourceView = sender
                    popover.sourceRect = sender.bounds
                    popover.permittedArrowDirections = .down
                }
                
                self.present(avc, animated: true, completion: nil)
            }
        }
    }
    
    @IBAction func deletePhoto(_ sender: UIButton) {
        let asset = model.selectedAsset
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset])
        }, completionHandler: nil)
    }
    
    @IBAction func toggleFavorite(_ sender: UIButton) {
        let asset = model.selectedAsset
        let newState = !asset.isFavorite
        
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = newState
        }, completionHandler: nil)
    }
    
    func doClose(_ interactive: Bool) {
        if let navController = presentingViewController as? UINavigationController,
            gridViewController = navController.topViewController as? GridViewController {
            gridViewController.setSelectedIndex(model.selectedIndex)
            let imageView = gridViewController.imageViewForIndex(model.selectedIndex)!
            let pageView = pageViews[model.selectedIndex]!
            
            if traitCollection.verticalSizeClass == .regular {
                hideStatusBar(false)
            }
            
            if interactive {
                swipeDismissTransition = PhotoViewSwipeDismissTransition(destImageView: imageView, sourceImageView: pageView.imageView)
            }
            else {
                dismissTransition = PhotoViewDismissTransition(destImageView: imageView, sourceImageView: pageView.imageView)
                swipeDismissTransition = nil
            }
            
            navController.dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func close(_ sender: UIButton) {
        doClose(false)
    }
    
    func viewDidPan(_ gr: UIPanGestureRecognizer) {
        switch gr.state {
        case .began:
            doClose(true)
        default:
            break
        }
        
        swipeDismissTransition?.handlePan(panRecognizer: gr)
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
    
    func loadPage(_ page: Int, requestFullImage: Bool) {
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
            heartButton.setImage(buttonImageForFavorite(asset.isFavorite), for: UIControlState())
            yearLabel.text = String("  \(asset.creationDate!.year)  ")
        }
        
        // if we already have a view with a full image or
        // if we don't need the full image
        // make sure it's layed out correctly
        if let pageView = pageViews[page] {
            if !requestFullImage || !pageView.imageIsDegraded {
                pageView.frame = frame
                if requestFullImage {
                    shareButton.isEnabled = true
                    deleteButton.isEnabled = true
                    heartButton.isEnabled = true
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
        imageManager.requestImage(for: asset, targetSize: cacheSize, contentMode: .aspectFill, options: nil, resultHandler: { (result, userInfo) -> Void in
            if let image = result {
                // NSLog("Cache Result with image for page \(page) requestFullImage: \(requestFullImage) iamgeSize: \(image.size.width), \(image.size.height)");
                pageView.image = image
                if page == self.model.selectedIndex {
                    self.shareButton.isEnabled = false
                    self.deleteButton.isEnabled = false
                    self.heartButton.isEnabled = false
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
    
    func loadHighQualityImageForAsset(_ asset: PHAsset, page: Int) {
        let options = PHImageRequestOptions()
        let pageView = pageViews[page]!
        
        options.progressHandler  = {(progress : Double, error: NSError?, stop: UnsafeMutablePointer<ObjCBool>, userInfo: [NSObject : AnyObject]?) -> Void in
            DispatchQueue.main.async {
                pageView.updateProgress(progress)
                
                if error != nil {
                    pageView.fullImageUnavailable = true
                }
            }
        }
        
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        
        pageView.imageRequestId = PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { (result, userInfo) -> Void in
            if let image = result {
                UpgradeManager.highQualityViewCount += 1
                pageView.image = image
                pageView.imageIsDegraded = false
                if page == self.model.selectedIndex {
                    self.shareButton.isEnabled = true
                    self.heartButton.isEnabled = true

                    if #available(iOS 9.0, *) {
                        self.deleteButton.isEnabled = !asset.sourceType.contains(.typeiTunesSynced)
                    } else {
                        self.deleteButton.isEnabled = true
                    }
                }
            }
            
            if let _ = userInfo?[PHImageErrorKey] as? NSError {
                pageView.fullImageUnavailable = true
            }
        }
    }
    
    func purgePage(_ page: Int) {
        guard page >= 0 && page < pageViews.count else {
            return
        }
        
        // Remove a page from the scroll view and reset the container array
        if let pageView = pageViews[page] {
            if let requestId = pageView.imageRequestId {
                PHImageManager.default().cancelImageRequest(requestId)
                pageView.imageRequestId = nil
            }
            pageView.image = nil
            pageView.removeFromSuperview()
            pageViews[page] = nil
        }
    }
    
    func cancelPageImageRequest(_ page: Int) {
        guard page >= 0 && page < pageViews.count else {
            return
        }
        
        if let pageView = pageViews[page] {
            if let requestId = pageView.imageRequestId {
                PHImageManager.default().cancelImageRequest(requestId)
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
        stride(from: 0, to: firstPage, by: 1).forEach(purgePage)
        
        // Load pages in our range
        (firstPage...lastPage).forEach { loadPage($0, requestFullImage: $0 == page) }
        
        // Purge anything after the last page
        stride(from: model.assets.count, to: lastPage, by: -1).forEach(purgePage)
    }
    
    func cancelAllImageRequests() {
        pageViews.indices.forEach(cancelPageImageRequest)
    }
    
    func purgeAllViews() {
        pageViews.indices.forEach(purgePage)
    }
    
    func contentOffsetForPageAtIndex(_ index : Int) -> CGPoint {
        let pageWidth = scrollView.bounds.size.width;
        let newOffset = CGFloat(index) * pageWidth;
        return CGPoint(x: newOffset, y: 0);
    }
    
    // MARK: UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == self.scrollView {
            loadVisiblePages()
        }
    }

    // MARK: UIViewControllerTransitioningDelegate
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return presentTransition
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if swipeDismissTransition != nil {
            return swipeDismissTransition
        }
        
        return dismissTransition
    }
    
    func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return swipeDismissTransition
    }
    
    // MARK: PHPhotoLibraryChangeObserver
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {
            self.processLibraryChange(changeInstance)
        }
    }
    
    private func processLibraryChange(_ changeInstance: PHChange) {
        let newAssets:[PHAsset] = model.assets.flatMap {
            if let changeDetails = changeInstance.changeDetails(for: $0) {
                return changeDetails.objectWasDeleted ? nil : changeDetails.objectAfterChanges as? PHAsset
            }
            else {
                return $0
            }
        }
        
        if newAssets.isEmpty {
            presentingViewController?.dismiss(animated: true, completion: nil);
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
            heartButton.setImage(buttonImageForFavorite(asset.isFavorite), for: UIControlState())
        }
    }
    
    // MARK: ZoomingPhotoViewDelegate
    func hideControls(_ hide: Bool) {
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
