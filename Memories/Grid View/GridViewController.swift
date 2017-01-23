//
//  GridViewController.swift
//  Memories
//
//  Created by Michael Brown on 18/06/2015.
//  Copyright (c) 2015 Michael Brown. All rights reserved.
//

import UIKit
import Photos
import Cartography
import PHAssetHelper
import ReactiveSwift
import ReactiveCocoa
import Result

extension UICollectionView {
    func indexPathsForElements(in rect : CGRect) -> [IndexPath] {
        if let allLayoutAttributes = self.collectionViewLayout.layoutAttributesForElements(in: rect) {
            return allLayoutAttributes.map() {$0.indexPath}
        }
        
        return [IndexPath]()
    }
}

class GridViewController: UICollectionViewController
{
    struct CellIdentifier {
        static let photoCell = "PhotoCell"
        static let yearHeader = "YearHeader"
    }
    
    // If the size is too large then PhotoKit doesn't return an optimal image size
    // see rdar://25181601 (https://openradar.appspot.com/radar?id=6158824289337344)
    let gridThumbnailSize = CGSize(width: 256, height: 256)
    
    var model : GridViewModel!
    var disposeables = [Disposable?]()

    var statusBarVisible = true
    
    var imageManager : PHCachingImageManager?
    var previousPreheatRect : CGRect = .zero
    var cellSize : CGSize = .zero
    
    var titleView : UILabel!
    let noPhotosLabel : UILabel
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    var topPullView : PullView? = nil
    var bottomPullView : PullView? = nil
    var shouldReload = false
    var reloadNext = false

    let RELEASE_THRESHOLD : CGFloat = 100.0
    
    let timeFormatter = DateComponentsFormatter()
    
    required init?(coder aDecoder: NSCoder) {
        noPhotosLabel = UILabel()
        noPhotosLabel.backgroundColor = UIColor.clear
        noPhotosLabel.font = UIFont.systemFont(ofSize: 16)
        noPhotosLabel.textColor = UIColor.white
        
        super.init(coder: aDecoder)
    }
    
    deinit {
        disposeables.forEach {
            $0?.dispose()
        }
    }
    
    private func bindToModel() {
        model.resultsDate.signal.observe(on: QueueScheduler.main)
            .skipRepeats(==)
            .observeValues { [weak self] date in
                print("resultsDate changed: \(date)")
                self?.refreshData(for: date)
        }
        
        model.title.signal.observe(on: QueueScheduler.main)
            .observeValues { [weak self] title in
                self?.titleView.text = title
                self?.titleView.sizeToFit()
        }
        
        model.sectionChanged.observe(on: QueueScheduler.main)
            .observeValues { [weak self]  changes in
                self?.updateSection(with: changes)
        }
    }
    
    private func startImageManager() {
        checkPhotosPermission().observe(on: QueueScheduler.main)
            .startWithValues { [weak self] status in
                switch status {
                case .authorized:
                    self?.model.photosAllowed.value = true
                    self?.imageManager = PHCachingImageManager()
                    
                    let startDate = Date()
                    if let date = NotificationManager.launchDate() {
                        self?.model.date.value = date
                    } else {
                        self?.model.date.value = startDate
                    }
                    
                    self?.registerObservers()
                case .denied, .restricted:
                    self?.showHideNoPhotosLabel(NSLocalizedString("No access to Photo Library :(", comment: ""))
                case .notDetermined:
                    break
                }
        }
    }
    
    private func registerObservers() {
        disposeables = [
            NotificationCenter.default.reactive
                .notifications(forName: NSNotification.Name.UIApplicationDidBecomeActive)
                .observeValues{ [weak self] _ in
                    self?.appDidBecomeActive()
            }]
    }
    
    private func createTitleView() {
        titleView = UILabel(frame: CGRect.zero).with {
            $0.backgroundColor = UIColor.clear
            $0.font = UIFont.systemFont(ofSize: 16)
            $0.textColor = UIColor.white
            $0.isUserInteractionEnabled = true
            $0.text = NSLocalizedString("Memories", comment: "")
        }
        self.navigationItem.titleView = titleView
        titleView.sizeToFit()
        
        let tgr = UITapGestureRecognizer(target: self, action: #selector(GridViewController.titleTapped(_:)))
        titleView.addGestureRecognizer(tgr)
    }
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createTitleView()
        
        model = GridViewModel()
        bindToModel()
        startImageManager()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureCellSize(for: view.bounds.size)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateCachedAssets()
        
        guard noPhotosLabel.text == nil else { return }
        showHideNoPhotosLabel(NSLocalizedString("Loading...", comment: ""))
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        configureCellSize(for: size)
        updateCachedAssets()
        
        coordinator.animate(alongsideTransition: { (context : UIViewControllerTransitionCoordinatorContext) -> Void in
            self.collectionView?.performBatchUpdates(nil, completion: nil)
            }, completion: {(context : UIViewControllerTransitionCoordinatorContext) -> Void in
                self.adjustPullViewPositions()
            })
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        let largeScreen = newCollection.verticalSizeClass == .regular &&
                        newCollection.horizontalSizeClass == .regular
        let contentMode: UIViewContentMode = largeScreen ? .scaleAspectFit : .scaleAspectFill
        
        coordinator.animate(alongsideTransition: { (context : UIViewControllerTransitionCoordinatorContext) -> Void in
            self.collectionView!.visibleCells.forEach {
                let gridCell = $0 as! GridViewCell
                gridCell.imageView?.contentMode = contentMode
            }
        }, completion: nil)
    }
    
    override var prefersStatusBarHidden: Bool   {
        get {
            return !statusBarVisible || traitCollection.verticalSizeClass == .compact
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Observer handlers
    private func appDidBecomeActive() {
        if let date = NotificationManager.launchDate() , self.model.photosAllowed.value {
            self.model.date.value = date
        }
    }
    
    private func updateSection(with changes: SectionChanges) {
        if changes.nonIncremental {
            collectionView?.reloadSections(IndexSet(integer: changes.section))
        }
        else {
            collectionView?.performBatchUpdates({ 
                self.collectionView?.deleteItems(at: changes.removed)
                self.collectionView?.insertItems(at: changes.inserted)
                self.collectionView?.reloadItems(at: changes.changed)
                if changes.newItemCount == 0 {
                    self.collectionView?.deleteSections(IndexSet(integer: changes.section))
                }
            }, completion: nil)
        }
        
        showHideNoPhotosLabel()
        resetCachedAssets()
    }
    
    private func refreshData(for date: Date) {
        resetCachedAssets()
        collectionView?.reloadData()
        collectionView!.setContentOffset(CGPoint(x: 0, y: -collectionView!.contentInset.top), animated: false)
        showHideNoPhotosLabel()
        
        createOrUpdatePullViews(with: date as Date)
        showHideBlur(false)
    }
    
    // MARK: - Actions
    func titleTapped(_ tgr: UITapGestureRecognizer) {
        let sourceView = tgr.view!
        
        if let datePickerVC = storyboard?.instantiateViewController(withIdentifier: "datePicker") as? DatePickerViewController {
            datePickerVC.modalPresentationStyle = UIModalPresentationStyle.popover
            datePickerVC.preferredContentSize = CGSize(width: 200, height: 240)
            
            if let popoverPresentationController = datePickerVC.popoverPresentationController {
                popoverPresentationController.sourceView = sourceView
                popoverPresentationController.sourceRect = CGRect(x: 0, y: 0, width: sourceView.frame.size.width, height: sourceView.frame.size.height)
                popoverPresentationController.delegate = self
                popoverPresentationController.backgroundColor = UIColor.black.withAlphaComponent(0.2)
            }
            
            datePickerVC.initialDate = model.date.value
            present(datePickerVC, animated: true, completion: nil)
        }
    }
}

// MARK: - StatusBarViewController
extension GridViewController: StatusBarViewController {
    func hideStatusBar(_ hide: Bool) {
        statusBarVisible = !hide
        UIView.animate(withDuration: 0.25) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
}


// MARK: - UIPopoverPresentationControllerDelegate
extension GridViewController: UIPopoverPresentationControllerDelegate {
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        return true
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        let datePickerVC = popoverPresentationController.presentedViewController as! DatePickerViewController
        
        if let selectedDate = datePickerVC.selectedDate, (selectedDate != model.date.value) {
            model.date.value = datePickerVC.selectedDate!
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
}
    
// MARK: - UICollectionViewDelegate
extension GridViewController {
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let photoViewController = storyboard?.instantiateViewController(withIdentifier: "photoViewController") as? PhotoViewController {
            photoViewController.model = model.photoViewModel(for: indexPath)
            photoViewController.delegate = self
            if let cell = collectionView.cellForItem(at: indexPath) as? GridViewCell, let imageView = cell.imageView {
                photoViewController.presentTransition = PhotoViewPresentTransition(sourceImageView: imageView)
                photoViewController.transitioningDelegate = photoViewController
                photoViewController.modalPresentationStyle = .custom
                
                present(photoViewController, animated: true, completion: nil)
            }
        }
    }
}

// MARK: - UICollectionViewDataSource
extension GridViewController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return model.sectionCount
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return model.numberOfItems(in: section)
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellIdentifier.photoCell, for: indexPath) as! GridViewCell
        
        // Increment the cell's tag
        let currentTag = cell.tag + 1
        cell.tag = currentTag
        
        cell.imageView?.contentMode = thumbnailContentMode
        
        if let asset = model.asset(at: indexPath) {
            imageManager?.requestImage(for: asset, targetSize: gridThumbnailSize, contentMode: .aspectFill, options: nil) { (result : UIImage?, info : [AnyHashable : Any]?) -> Void in
                if let image = result, cell.tag == currentTag {
                    // Only update the thumbnail if the cell tag hasn't changed. Otherwise, the cell has been re-used.
                    cell.thumbnailImage = image
                    cell.durationLabel?.text = asset.mediaType == .video ? " \(self.timeFormatter.videoDuration(from: asset.duration) ?? "") " : ""
                }
            }
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CellIdentifier.yearHeader, for: indexPath) as! GridHeaderView
        headerView.label.text = String(model.year(for: (indexPath as NSIndexPath).section))
        
        return headerView
    }
}

// MARK: - PhotoViewControllerDelegate
extension GridViewController: PhotoViewControllerDelegate {
    func setSelected(index: Int) {
        collectionView?.selectItem(at: model.indexPath(for: index), animated: false, scrollPosition: .centeredVertically)
    }
    
    func imageView(atIndex index: Int) -> UIImageView? {
        guard let cell = collectionView?.cellForItem(at: model.indexPath(for: index)) as? GridViewCell else {
            return nil
        }
        
        return cell.imageView
    }
}
    
// MARK: - UICollectionViewDelegateFlowLayout
extension GridViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSize
    }
}

// MARK: - UIScrollViewDelegate
extension GridViewController {

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCachedAssets()
        adjustPullViewPositions()
    }
    
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard let tpv = topPullView, let bpv = bottomPullView, decelerate else {
            return
        }
        
        shouldReload = false
        
        if tpv.willRelease {
            shouldReload = true
            reloadNext = false
        }
        if bpv.willRelease {
            shouldReload = true
            reloadNext = true
        }
        
        if shouldReload {
            showHideBlur(true)
        }
    }
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if shouldReload {
            if reloadNext {
                model.goToNextDay()
            } else {
                model.goToPreviousDay()
            }
        }
    }

    // MARK: Scroll to Change Date
    func createOrUpdatePullViews(with date: Date) {
        if let tpv = topPullView, let bpv = bottomPullView {
            tpv.date = date.previousDay()
            bpv.date = date.nextDay()
        } else {
            topPullView = PullView(frame: CGRect(x: 0, y: 0, width: collectionView!.frame.width, height: 0), date: date.previousDay())
            bottomPullView = PullView(frame: CGRect(x: 0, y: 0, width: collectionView!.frame.width, height: 0), date: date.nextDay())
            
            collectionView!.addSubview(topPullView!)
            collectionView!.addSubview(bottomPullView!)
        }
    }
    
    func adjustPullViewPositions() {
        guard let tpv = topPullView, let bpv = bottomPullView else {
            return
        }
        
        let topOffset = topLayoutGuide.length
        
        let resizeView = { (view: PullView, yPosition: CGFloat, viewHeight: CGFloat) -> Void in
            view.frame = CGRect(x: 0, y: yPosition, width: self.collectionView!.frame.width, height: viewHeight)
            view.alpha = pow(fabs(viewHeight), 2) / pow(self.RELEASE_THRESHOLD, 2)
            view.willRelease = fabs(viewHeight) >= self.RELEASE_THRESHOLD
        }
        
        // handle top pull view
        if collectionView!.contentOffset.y <= -topOffset {
            let viewHeight = topOffset + collectionView!.contentOffset.y
            resizeView(tpv, 0, viewHeight)
        } else if tpv.frame.height > 0 {
            tpv.frame = CGRect(x: 0, y: 0, width: collectionView!.frame.width, height: 0)
        }
        
        // handle bottom pull view
        let offset = collectionView!.contentOffset.y
        let boundsHeight = collectionView!.bounds.height
        let sizeHeight = collectionView!.contentSize.height
        let bottomOfView = max(sizeHeight, boundsHeight - topOffset)
        let y = offset + boundsHeight;
        
        if y >= bottomOfView {
            let viewHeight = y - bottomOfView
            let yPosition = bottomOfView
            
            resizeView(bpv, yPosition, viewHeight)
        } else if bpv.frame.height > 0 {
            bpv.frame = CGRect(x: 0, y: 0, width: collectionView!.frame.width, height: 0)
        }
    }
}


// MARK: - Asset Caching
extension GridViewController {
    fileprivate func resetCachedAssets() {
        imageManager?.stopCachingImagesForAllAssets()
        previousPreheatRect = CGRect.zero
    }
    
    fileprivate func updateCachedAssets() {
        guard let imageManager = imageManager,
            isViewLoaded && view.window != nil else {
                return
        }
        
        // The preheat window is twice the height of the visible rect
        let bounds = collectionView!.bounds;
        let preheatRect = bounds.insetBy(dx: 0.0, dy: -0.5 * bounds.height);
        
        // If scrolled by a "reasonable" amount...
        let delta = abs(preheatRect.midY - previousPreheatRect.midY);
        if delta > bounds.height / 3.0 {
            var addedIndexPaths = [IndexPath]()
            var removedIndexPaths = [IndexPath]()
            
            computeDifferenceBetweenRects(previousPreheatRect, preheatRect,
                                          removedHandler: {
                                            removedIndexPaths += self.collectionView!.indexPathsForElements(in: $0)
            },
                                          addedHandler: {
                                            addedIndexPaths += self.collectionView!.indexPathsForElements(in: $0)
            })
            
            let assetsToStartCaching = assets(at: addedIndexPaths)
            let assetsToStopCaching = assets(at: removedIndexPaths)
            
            imageManager.startCachingImages(for: assetsToStartCaching, targetSize: gridThumbnailSize, contentMode: .aspectFill, options: nil)
            imageManager.stopCachingImages(for: assetsToStopCaching, targetSize: gridThumbnailSize, contentMode: .aspectFill, options: nil)
            
            previousPreheatRect = preheatRect
        }
    }
    
    private func computeDifferenceBetweenRects(_ oldRect: CGRect, _ newRect: CGRect, removedHandler: (CGRect) -> (), addedHandler: (CGRect) -> ()) {
        if newRect.intersects(oldRect) {
            let oldMaxY = oldRect.maxY
            let oldMinY = oldRect.minY
            let newMaxY = newRect.maxY
            let newMinY = newRect.minY
            
            if newMaxY > oldMaxY {
                let rectToAdd = CGRect(x: newRect.origin.x, y: oldMaxY, width: newRect.size.width, height: (newMaxY - oldMaxY))
                addedHandler(rectToAdd)
            }
            if oldMinY > newMinY {
                let rectToAdd = CGRect(x: newRect.origin.x, y: newMinY, width: newRect.size.width, height: (oldMinY - newMinY))
                addedHandler(rectToAdd)
            }
            if newMaxY < oldMaxY {
                let rectToRemove = CGRect(x: newRect.origin.x, y: newMaxY, width: newRect.size.width, height: (oldMaxY - newMaxY))
                removedHandler(rectToRemove)
            }
            if oldMinY < newMinY {
                let rectToRemove = CGRect(x: newRect.origin.x, y: oldMinY, width: newRect.size.width, height: (newMinY - oldMinY))
                removedHandler(rectToRemove)
            }
        } else {
            addedHandler(newRect);
            removedHandler(oldRect);
        }
    }
    
    private func assets(at indexPaths : [IndexPath]) -> [PHAsset] {
        return indexPaths.flatMap() {
            self.model.asset(at: $0)
        }        
    }
}

// MARK: - Helpers
extension GridViewController {
    fileprivate func showHideBlur(_ show: Bool) {
        if show {
            let window = UIApplication.shared.keyWindow!
            var frame = window.frame
            frame.origin.y += topLayoutGuide.length
            
            blurView.frame = frame
            window.addSubview(blurView)
        } else {
            blurView.removeFromSuperview()
        }
    }
    
    fileprivate func configureCellSize(for viewSize : CGSize) {
        let minWidth = CGFloat(90.0)
        let viewWidth = viewSize.width
        let maxCellsPerRow: CGFloat = viewSize.width < viewSize.height ? 5 : 7
        let cellsPerRow = min(floor(viewWidth / minWidth), maxCellsPerRow)
        let cellWidth = floor((viewWidth  - (cellsPerRow - 1)) / cellsPerRow)
        
        let cellSize = CGSize(width: cellWidth, height: cellWidth)
        self.cellSize = cellSize
    }
    
    fileprivate func showHideNoPhotosLabel(_ text: String? = nil) {
        // make sure views have been layed out properly
        guard topLayoutGuide.length != 0 else {
            return
        }
        
        noPhotosLabel.text = text ?? NSLocalizedString("Sorry, no photos for this date :(", comment: "")
        
        if model.sectionCount == 0 && noPhotosLabel.superview == nil {
            collectionView?.addSubview(noPhotosLabel)
            
            constrain(noPhotosLabel, collectionView!) { noPhotosLabel, collectionView in
                noPhotosLabel.centerX == collectionView.centerX
                noPhotosLabel.centerY == collectionView.centerY - topLayoutGuide.length
            }
        }
        
        if model.sectionCount > 0 && noPhotosLabel.superview != nil {
            noPhotosLabel.removeFromSuperview()
        }
    }
}

// MARK: - Photos Authorization
extension GridViewController {
    fileprivate func checkPhotosPermission() -> SignalProducer<PHAuthorizationStatus, NoError> {
        let authStatus = PHPhotoLibrary.authorizationStatus();
        
        return SignalProducer<PHAuthorizationStatus, NoError> { observer, _ in
            observer.send(value: authStatus)
            
            var alert: UIAlertController?
            
            switch authStatus {
            case .authorized:
                observer.send(value: authStatus)
                observer.sendCompleted()
            case .notDetermined:
                alert = UIAlertController(title: NSLocalizedString("Let Memories access Photos?", comment: ""), message: NSLocalizedString("Memories can only work if it has access to your photos. If you tap 'Allow' iOS will ask your permission.", comment: ""), preferredStyle: .alert)
                let allow = UIAlertAction(title: NSLocalizedString("Allow", comment: ""), style: .default) { (action) -> Void in
                    PHPhotoLibrary.requestAuthorization { status in
                        observer.send(value: status)
                    }
                }
                let deny = UIAlertAction(title: NSLocalizedString("Not Now", comment: ""), style: .cancel)
                alert?.addAction(deny)
                alert?.addAction(allow)
            case .denied:
                alert = UIAlertController(title: NSLocalizedString("No Access to Photos", comment: ""), message: NSLocalizedString("You have Denied access to Photos for Memories. In order for Memories to work you must enable this access in Settings. Would you like to do this now?", comment: ""), preferredStyle: .alert)
                let settings = UIAlertAction(title: NSLocalizedString("Settings", comment: ""), style: .default) { (action) -> Void in
                    let url = URL(string: UIApplicationOpenSettingsURLString)
                    UIApplication.shared.openURL(url!);
                }
                let nothanks = UIAlertAction(title: NSLocalizedString("No thanks", comment: ""), style: .cancel)
                alert?.addAction(nothanks)
                alert?.addAction(settings)
            case .restricted:
                alert = UIAlertController(title: NSLocalizedString("No Access to Photos", comment: ""), message: NSLocalizedString("Access to Photos has been restricted on this device. Unfortunately this means Memories will not work until this is changed.", comment: ""), preferredStyle: .alert)
                let ok = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default)
                alert?.addAction(ok)
            }
            
            if let alert = alert {
                alert.reactive.trigger(for: #selector(alert.viewWillDisappear(_:))).observeValues {
                    observer.sendCompleted()
                }
                
                UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true)
            }
        }
    }
}


