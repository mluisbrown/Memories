//
//  PhotoViewController.swift
//  Memories
//
//  Created by Michael Brown on 08/07/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit
import Photos
import DACircularProgress
import Cartography
import ReactiveSwift

protocol PhotosViewControllerDelegate {
    func setCurrent(index: Int)
    func imageView(atIndex: Int) -> UIImageView?
}

class PhotosViewController: UIViewController,
    UIScrollViewDelegate,
    UIViewControllerTransitioningDelegate,
    UIGestureRecognizerDelegate,
    PHPhotoLibraryChangeObserver,
    ZoomingPhotoViewDelegate
{
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var heartButton: UIButton!
    @IBOutlet weak var yearLabel: UILabel!
    let shareProgressView = DACircularProgressView().with {
        $0.isHidden = true
    }

    let padding = CGFloat(10);
    
    let heartFullImg = #imageLiteral(resourceName: "heart-full").withRenderingMode(.alwaysTemplate)
    let heartEmptyImg = #imageLiteral(resourceName: "heart-empty").withRenderingMode(.alwaysTemplate)
    
    var upgradePromptShown = false
    var initialOffsetSet = false
    var initialPage : Int!
    var model : PhotosViewModel!
    var pageViews = [ZoomingPhotoView?]()
    var delegate: PhotosViewControllerDelegate?

    struct PanState {
        let pageView: ZoomingPhotoView?
        let imageView: UIView?
        let destImageView: UIImageView?
        let transform: CGAffineTransform
        let center: CGPoint
        let panHeight: CGFloat
    }
    
    var initialPanState: PanState?
    
    var presentTransition: PhotosViewPresentTransition?
    var dismissTransition: PhotosViewDismissTransition?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func bindToModel() {
        model.indexLoadedAndVisible.signal
        .observeValues { [weak self] in
            guard let sself = self,
                let pageView = sself.pageViews[$0] else {
                return
            }
            
            let photoViewModel = sself.model.photoViewModels[$0]
            
            self?.didLoad(pageView: pageView, for: photoViewModel.asset, hiRes: !photoViewModel.imageIsPreview.value)
        }
    }
    
    var controlsHidden: Bool {
        get {
            return closeButton.alpha == 0
        }
    }

    private func setControls(alpha: CGFloat) {
        [shareButton, deleteButton, closeButton, heartButton, yearLabel].forEach {
            $0.alpha = alpha
        }
    }
    
    private func buttonImage(forFavorite favorite: Bool) -> UIImage {
        return favorite ? heartFullImg : heartEmptyImg
    }
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bindToModel()

        initialPage = model.currentIndex
        PHPhotoLibrary.shared().register(self);
        
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(PhotosViewController.viewDidPan)).with {
            $0.delegate = self
        }
        view.addGestureRecognizer(panRecognizer)
    
        shareProgressView.with {
            $0.trackTintColor = UIColor.clear
            $0.thicknessRatio = 0.1
            $0.indeterminateDuration = 1
            $0.indeterminate = 0
            $0.setProgress(0.33, animated: false)
        }
        view.addSubview(shareProgressView)
        constrain(view, shareProgressView) { view, shareProgressView in
            shareProgressView.width == 40
            shareProgressView.height == 40
            shareProgressView.left == view.left + 10
            shareProgressView.bottom == view.bottom - 10
        }
    }

    override func viewDidLayoutSubviews() {
        setupViews()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        initialPage = model.currentIndex
        initialOffsetSet = false
        
        // disable delegate to avoid calls to scrollViewDidScroll
        // whilst transition is in progress
        // the delegate is reset in setupViews()
        scrollView.delegate = nil
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Actions
    @IBAction func sharePhoto(_ sender: UIButton) {
        let page = model.currentIndex
        let pageModel = model.photoViewModels[page]
        let asset = pageModel.asset
        
        switch asset.mediaType {
        case .image where asset.mediaSubtypes == .photoLive:
            if let assetResource = pageModel.assetResource.value,
               case let .livePhoto(livePhoto) = assetResource {
                share(media: [livePhoto], from: sender)
            }
        case .image:
            let options = PHImageRequestOptions()
            options.version = .current
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImageData(for: asset, options: options) {
                [weak self] imageData, dataUTI, orientation, info in
                
                if let imageData = imageData {
                    self?.share(media: [imageData], from: sender)
                }
            }
        case .video:
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .automatic
            options.isNetworkAccessAllowed = true
            
            UIView.animate(withDuration: 0.25) {
                sender.alpha = 0
                self.shareProgressView.show(loading: true)
            }
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] asset, audioMix, info in
                UIView.animate(withDuration: 0.25, animations: {
                    self?.shareProgressView.show(loading: false)
                    sender.alpha = 1
                }) { _ in
                    if let urlAsset = asset as? AVURLAsset {
                        self?.share(media: [urlAsset.url], from: sender)
                    }
                }
            }
            break
        default:
            break
            
        }
    }
    
    private func share(media: [Any], from view: UIView) {
        let avc = UIActivityViewController(activityItems: media, applicationActivities: nil)
        if let popover = avc.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
            popover.permittedArrowDirections = .down
        }
        
        self.present(avc, animated: true, completion: nil)
    }
    
    @IBAction func deletePhoto(_ sender: UIButton) {
        let asset = model.currentAsset
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(NSArray(array: [asset]))
        }, completionHandler: nil)
    }
    
    @IBAction func toggleFavorite(_ sender: UIButton) {
        let asset = model.currentAsset
        let newState = !asset.isFavorite
        
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = newState
        }, completionHandler: nil)
    }
    
    private func doClose() {
        guard let delegate = delegate else {
            return
        }
        
        if let imageView = delegate.imageView(atIndex: model.currentIndex),
            let pageView = pageViews[model.currentIndex] {
            dismissTransition = PhotosViewDismissTransition(destImageView: imageView, sourceImageView: pageView.mediaView)
        }
        else {
            dismissTransition = nil
        }
        
        presentingViewController?.dismiss(animated: true) {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
            self.cancelAllImageRequests()
            self.purgeAllViews()
        }
    }
    
    @IBAction func close(_ sender: UIButton) {
        doClose()
    }
    
    func viewDidPan(_ gr: UIPanGestureRecognizer) {
        switch gr.state {
        case .began:
            let startPoint = gr.location(in: gr.view)
            
            let pageView = pageViews[model.currentIndex]
            let imageView = pageViews[model.currentIndex]!.mediaView
            initialPanState = PanState(pageView: pageView,
                                       imageView: imageView,
                                       destImageView: delegate?.imageView(atIndex: model.currentIndex),
                                       transform: imageView.transform,
                                       center: imageView.center,
                                       panHeight: gr.view!.bounds.height - startPoint.y)
            initialPanState?.destImageView?.isHidden = true
            initialPanState?.pageView?.prepareForDragging()
            
        case .changed:
            guard let panState = initialPanState else { break }
            let translation = gr.translation(in: gr.view)
            let yPercent = translation.y / panState.panHeight
            let percent = yPercent <= 0 ? 0 : yPercent
            let alpha = 1 - percent
            let scale = (1 - percent / 2)
            
            panState.imageView?.center = CGPoint(x: panState.center.x + translation.x, y: panState.center.y + translation.y)
            panState.imageView?.transform = panState.transform.scaledBy(x: scale, y: scale)
            
            view.backgroundColor = UIColor.black.withAlphaComponent(alpha)
            if !controlsHidden { setControls(alpha: alpha) }

        case .ended, .cancelled:
            guard let panState = initialPanState else { break }

            let velocity = gr.velocity(in: gr.view)
            if velocity.y < 0 || gr.state == .cancelled {
                UIView.animate(withDuration: 0.25, animations: {
                    panState.imageView?.center = panState.center
                    panState.imageView?.transform = panState.transform
                    self.view.backgroundColor = UIColor.black
                    if !self.controlsHidden { self.setControls(alpha: 1) }
                }) { finished in
                    panState.destImageView?.isHidden = false
                    panState.pageView?.dragWasCancelled()
                }
            }
            else {
                doClose()
            }

            initialPanState = nil

        default:
            break
        }
    }
    
    // MARK: - Internal implementation
    private func setupViews() {
        let pageCount = model.count

        if pageViews.count == 0 {
            for _ in 0 ..< pageCount {
                pageViews.append(nil)
            }
            initialPage = model.currentIndex
            initialOffsetSet = false
        }

        let pagesScrollViewSize = scrollView.bounds.size

        doWithScrollViewDelegateDisabled {
            scrollView.contentSize = CGSize(width: pagesScrollViewSize.width * CGFloat(pageCount), height: pagesScrollViewSize.height)
            if (!initialOffsetSet) {
                scrollView.contentOffset = contentOffsetForPage(at: initialPage)
                initialOffsetSet = true
                
                loadVisiblePages(initialLoad: true)
            }
        }
    }
    
    private func doWithScrollViewDelegateDisabled(block: () -> ()) {
        scrollView.delegate = nil
        block()
        scrollView.delegate = self
    }
    
    private func didLoad(pageView: ZoomingPhotoView, for asset: PHAsset, hiRes: Bool) {
        shareButton.isEnabled = hiRes
        deleteButton.isEnabled = hiRes
        heartButton.isEnabled = !asset.sourceType.contains(.typeiTunesSynced) && hiRes
        
        pageView.didBecomeVisible()
    }
    
    private func loadVisiblePages(initialLoad: Bool = false) {
        // First, determine which page is currently visible
        let pageWidth = scrollView.bounds.size.width
        let fractionalPage = scrollView.contentOffset.x / pageWidth;
        let page = lround(Double(fractionalPage))
        
        guard initialLoad || page != model.currentIndex else {
            return
        }
        
        model.currentIndex = page
        delegate?.setCurrent(index: model.currentIndex)
        
        // Work out which pages you want to load
        let firstPage = page - 1
        let lastPage = page + 1
        
        // Purge anything before the first page
        stride(from: 0, to: firstPage, by: 1).forEach(purge)
        
        // Load pages in our range
        (firstPage...lastPage).forEach { load(page: $0, requestFullImage: $0 == page) }
        
        // Purge anything after the last page
        stride(from: model.count, to: lastPage, by: -1).forEach(purge)
    }
    
    private func load(page: Int, requestFullImage: Bool) {
        guard page >= 0 && page < model.count else {
            return
        }

        // setup the frame for the view
        let bounds = scrollView.bounds
        var frame = bounds
        frame.size.width -= (2.0 * padding);
        frame.origin.x = bounds.size.width * CGFloat(page) + padding
        frame.origin.y = 0.0

        let asset = model.photoViewModels[page].asset
        if page == self.model.currentIndex {
            heartButton.setImage(buttonImage(forFavorite: asset.isFavorite), for: UIControlState())
            yearLabel.text = String("  \(asset.creationDate!.year)  ")
        }
        
        let photoViewModel = model.photoViewModels[page]
        
        // if we already have a view with a full image or
        // if we don't need the full image
        // make sure it's layed out correctly
        if let pageView = pageViews[page] {
            if !requestFullImage || !photoViewModel.imageIsPreview.value {
                pageView.frame = frame
                if requestFullImage {
                    didLoad(pageView: pageView, for: asset, hiRes: true)
                } else {
                    pageView.willBecomeHidden()
                }
                return
            }
        }

        let pageView: ZoomingPhotoView
        
        if let pv = pageViews[page] {
            pageView = pv
        } else {
            pageView = ZoomingPhotoView(model: photoViewModel)
            pageView.photoViewDelegate = self
            scrollView.addSubview(pageView)
            pageViews[page] = pageView
        }
        pageView.frame = frame

        // always get a thumbnail first
        model.loadPreviewImageFor(index: page)
        
        // then get the full size image if required
        if requestFullImage {
            if !UpgradeManager.highQualityViewAllowed() {
                UpgradeManager.promptForUpgrade(in: self) {
                    if !$0 {
                        pageView.hideProgressView(true)
                    } else {
                        self.model.loadHighQualityAssetFor(index: page)
                    }
                }
                
                return
            }
            
            self.model.loadHighQualityAssetFor(index: page)
        }
    }

    private func cancelAllImageRequests() {
        model.cancelAllAssetRequests()
    }
    
    private func purgeAllViews() {
        pageViews.indices.forEach(purge)
    }
    
    private func purge(page: Int) {
        guard page >= 0 && page < pageViews.count else {
            return
        }
        
        // Remove a page from the scroll view and reset the container array
        if let pageView = pageViews[page] {
            pageView.removeFromSuperview()
            pageViews[page] = nil
            
            model.resetPhotoViewModelFor(index: page)
        }
    }
    
    private func contentOffsetForPage(at index : Int) -> CGPoint {
        let pageWidth = scrollView.bounds.size.width;
        let newOffset = CGFloat(index) * pageWidth;
        return CGPoint(x: newOffset, y: 0);
    }
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == self.scrollView {
            loadVisiblePages()
        }
    }

    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UISlider {
            return false
        }
        
        return true
    }
    
    
    // MARK: - UIViewControllerTransitioningDelegate
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return presentTransition
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return dismissTransition
    }
    
    // MARK: - PHPhotoLibraryChangeObserver
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {
            self.processLibraryChange(changeInstance)
        }
    }
    
    private func processLibraryChange(_ changeInstance: PHChange) {
        let newAssets:[PHAsset] = model.photoViewModels.flatMap {
            if let changeDetails = changeInstance.changeDetails(for: $0.asset) {
                return changeDetails.objectWasDeleted ? nil : changeDetails.objectAfterChanges as? PHAsset
            }
            else {
                return $0.asset
            }
        }
        
        if newAssets.isEmpty {
            presentingViewController?.dismiss(animated: true, completion: nil);
            return
        }
        
        let assetsDeleted = newAssets.count < model.count
        let newCurrentIndex = min(model.currentIndex, newAssets.count - 1)
        model = PhotosViewModel(assets: newAssets, currentIndex: newCurrentIndex)
        bindToModel()
        
        if assetsDeleted {
            purgeAllViews()
            pageViews = []
            
            setupViews()
        }
        else {
            let asset = model.currentAsset
            heartButton.setImage(buttonImage(forFavorite: asset.isFavorite), for: UIControlState())
        }
    }
    
    // MARK: - ZoomingPhotoViewDelegate
    func viewWasZoomedIn() {
        guard !controlsHidden else {
            return
        }
        
        setControls(alpha: 0)
    }
    
    func viewWasTapped() {
        setControls(alpha: controlsHidden ? 1 : 0)
    }
}
