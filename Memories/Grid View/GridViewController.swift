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

extension IndexSet {
    func indexPathsFromIndexes(in section : Int) -> [IndexPath] {
        var indexPaths = [IndexPath]()
        
        (self as NSIndexSet).enumerate ({index, stop in
            indexPaths.append(IndexPath(item: index, section: section))
        })
        
        return indexPaths
    }
}

extension UICollectionView {
    func indexPathsForElements(in rect : CGRect) -> [IndexPath] {
        if let allLayoutAttributes = self.collectionViewLayout.layoutAttributesForElements(in: rect) {
            return allLayoutAttributes.map() {$0.indexPath}
        }
        
        return [IndexPath]()
    }
}

class GridViewController: UICollectionViewController,
    UICollectionViewDelegateFlowLayout,
    PHPhotoLibraryChangeObserver,
    UIPopoverPresentationControllerDelegate,
    StatusBarViewController,
    PhotoViewControllerDelegate
{
    struct CellIdentifier {
        static let photoCell = "PhotoCell"
        static let yearHeader = "YearHeader"
    }
    
    // If the size is too large then PhotoKit doesn't return an optimal image size
    // see rdar://25181601 (https://openradar.appspot.com/radar?id=6158824289337344)
    let gridThumbnailSize = CGSize(width: 256, height: 256)
    
    var model : GridViewModel!

    var titleView : UILabel!
    var statusBarVisible = true
    
    var imageManager : PHCachingImageManager!
    var previousPreheatRect : CGRect = .zero
    var cellSize : CGSize = .zero
    var photosAllowed = false
    
    let noPhotosLabel : UILabel
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    var topPullView : PullView? = nil
    var bottomPullView : PullView? = nil
    var shouldReload = false
    var reloadNext = false

    let RELEASE_THRESHOLD : CGFloat = 100.0
    let dateFormatter = DateFormatter()
    let assetHelper = PHAssetHelper()
    
    required init?(coder aDecoder: NSCoder) {
        noPhotosLabel = UILabel()
        noPhotosLabel.backgroundColor = UIColor.clear
        noPhotosLabel.font = UIFont.systemFont(ofSize: 16)
        noPhotosLabel.textColor = UIColor.white
        
        super.init(coder: aDecoder)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dateFormatter.dateFormat = "MMMM dd"
        model = GridViewModel() { [weak self] date in
            guard let `self` = self else { return }
            self.resetCachedAssets()
            self.collectionView?.reloadData()
            self.collectionView!.setContentOffset(CGPoint(x: 0, y: -self.collectionView!.contentInset.top), animated: false)
            self.showHideNoPhotosLabel()
            
            self.createOrUpdatePullViews(with: date as Date)
            self.title = self.dateFormatter.string(from: date as Date).uppercased() + " ▾" // ▼
            self.showHideBlur(false)
        }
        
        checkPhotosPermission {
            self.photosAllowed = true
            self.imageManager = PHCachingImageManager()
            
            let startDate = Date()
            if let date = NotificationManager.launchDate() {
                self.model.date.value = date
            } else {
                self.model.date.value = startDate
            }
            
            PHPhotoLibrary.shared().register(self);
            NotificationCenter.default.addObserver(self, selector: #selector(GridViewController.appDidBecomeActive),
                name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(GridViewController.reloadPhotos),
                name: NSNotification.Name(rawValue: PHAssetHelper.sourceTypesChangedNotification), object: nil)
        }
    }

    override var title: String? {
        set {
            super.title = newValue
            
            let titleView : UILabel!
            if let aTitleView : UILabel = self.navigationItem.titleView as? UILabel  {
                titleView = aTitleView;
            } else {
                titleView = UILabel(frame: CGRect.zero);
                	titleView.backgroundColor = UIColor.clear
                titleView.font = UIFont.systemFont(ofSize: 16)
                titleView.textColor = UIColor.white
                titleView.isUserInteractionEnabled = true
                self.navigationItem.titleView = titleView
                
                let tgr = UITapGestureRecognizer(target: self, action: #selector(GridViewController.titleTapped(_:)))
                titleView.addGestureRecognizer(tgr)
            }

            titleView.text = newValue
            titleView.sizeToFit()
        }
        
        get {
            return super.title
        }
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

    // MARK: StatusBarViewController
    func hideStatusBar(_ hide: Bool) {
        statusBarVisible = !hide
        UIView.animate(withDuration: 0.25) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    // MARK: - Notification handlers
    func appDidBecomeActive() {
        if let date = NotificationManager.launchDate() , self.photosAllowed {
            self.model.date.value = date
        }
    }
    
    func reloadPhotos() {
        // force the date change to fire, but
        // with the same date, to reload the data
        model.date.value = model.date.value
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
    
    
    // MARK: - UIPopoverPresentationControllerDelegate
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
    
    // MARK: - UICollectionViewDelegate
    
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
    
    
    // MARK: - PhotoViewContollerDelegate
    func setSelected(index: Int) {
        collectionView?.selectItem(at: model.indexPath(for: index), animated: false, scrollPosition: .centeredVertically)
    }
    
    func imageView(atIndex index: Int) -> UIImageView? {
        guard let cell = collectionView?.cellForItem(at: model.indexPath(for: index)) as? GridViewCell else {
            return nil
        }
        
        return cell.imageView
    }
    
    // MARK: - UICollectionViewDataSource

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
            imageManager.requestImage(for: asset, targetSize: gridThumbnailSize, contentMode: .aspectFill, options: nil) { (result : UIImage?, info : [AnyHashable : Any]?) -> Void in
                if let image = result, cell.tag == currentTag {
                    // Only update the thumbnail if the cell tag hasn't changed. Otherwise, the cell has been re-used.
                    cell.thumbnailImage = image
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
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath) -> CGSize {
            return cellSize
    }
    
    
    // MARK: - UIScrollViewDelegate
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
    
    // MARK: - Scroll to Change Date
    
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
        
        let resizeView = {(view: PullView, yPosition: CGFloat, viewHeight: CGFloat) -> Void in
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
    
    // MARK: - PHPhotoLibraryChangeObserver

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { () -> Void in
            var cacheNeedsReset = false
            
            for section in (0..<self.model.sectionCount).reversed() {
                if let fetchResult = self.model.fetchResult(for: section),
                    let collectionChanges = changeInstance.changeDetails(for: fetchResult as! PHFetchResult<PHObject>) {
                    // get the new fetch result
                    self.model.setFetchResult(for: section, fetchResult: collectionChanges.fetchResultAfterChanges as! PHFetchResult<PHAsset>)
                    
                    if !collectionChanges.hasIncrementalChanges || collectionChanges.hasMoves {
                        self.collectionView?.reloadData()
                    } else {
                        self.collectionView?.performBatchUpdates({
                            if let removedIndexes = collectionChanges.removedIndexes {
                                if (removedIndexes.count != 0) {
                                    self.collectionView?.deleteItems(at: removedIndexes.indexPathsFromIndexes(in: section))
                                }
                            }
                            if let insertedIndexes = collectionChanges.insertedIndexes {
                                if (insertedIndexes.count != 0) {
                                    self.collectionView?.insertItems(at: insertedIndexes.indexPathsFromIndexes(in: section))
                                }
                            }
                            if let changedIndexes = collectionChanges.changedIndexes {
                                if (changedIndexes.count != 0) {
                                    self.collectionView?.reloadItems(at: changedIndexes.indexPathsFromIndexes(in: section))
                                }
                            }
                            if collectionChanges.fetchResultAfterChanges.count == 0 {
                                self.collectionView?.deleteSections(IndexSet(integer: section))
                            }
                        }, completion: nil)
                    }
                    
                    cacheNeedsReset = true
                }
            }
            
            if (cacheNeedsReset) {
                self.resetCachedAssets()
                self.assetHelper.refreshDatesMapCache()
            }
        }
    }

    // MARK: - Asset Caching
    
    func resetCachedAssets() {
        guard imageManager != nil else {
            return
        }
        
        imageManager.stopCachingImagesForAllAssets()
        previousPreheatRect = CGRect.zero
    }

    func updateCachedAssets() {
        guard isViewLoaded && view.window != nil && imageManager != nil else {
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

    func computeDifferenceBetweenRects(_ oldRect: CGRect, _ newRect: CGRect, removedHandler: (CGRect) -> (), addedHandler: (CGRect) -> ()) {
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
    
    func assets(at indexPaths : [IndexPath]) -> [PHAsset] {
        return indexPaths.flatMap() {
            self.model.asset(at: $0)
        }        
    }
    
    // MARK: - Helpers
    func showHideBlur(_ show: Bool) {
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
    
    
    func configureCellSize(for viewSize : CGSize) {
        let minWidth = CGFloat(90.0)
        let viewWidth = viewSize.width
        let maxCellsPerRow: CGFloat = viewSize.width < viewSize.height ? 5 : 7
        let cellsPerRow = min(floor(viewWidth / minWidth), maxCellsPerRow)
        let cellWidth = floor((viewWidth  - (cellsPerRow - 1)) / cellsPerRow)
        
        let cellSize = CGSize(width: cellWidth, height: cellWidth)
        self.cellSize = cellSize
    }
    
    func showHideNoPhotosLabel(_ text: String? = nil) {
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
    
    func checkPhotosPermission(completion handler : @escaping () -> ()) {
        let authStatus = PHPhotoLibrary.authorizationStatus();
        
        if authStatus == .authorized {
            handler()
        }

        if authStatus == .notDetermined {
            let alert = UIAlertController(title: NSLocalizedString("Let Memories access Photos?", comment: ""), message: NSLocalizedString("Memories can only work if it has access to your photos. If you tap 'Allow' iOS will ask your permission.", comment: ""), preferredStyle: .alert)
            let allow = UIAlertAction(title: NSLocalizedString("Allow", comment: ""), style: .default, handler: { (action) -> Void in
                PHPhotoLibrary.requestAuthorization({ (status) -> Void in
                    if status == .authorized {
                        DispatchQueue.main.async(execute: { () -> Void in
                            handler()
                        })
                    }
                })
            })
            let deny = UIAlertAction(title: NSLocalizedString("Not Now", comment: ""), style: .cancel, handler: { (action) -> Void in
                
            })
            alert.addAction(deny)
            alert.addAction(allow)
            
            UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
            return
        }
        
        if authStatus == .denied {
            let alert = UIAlertController(title: NSLocalizedString("No Access to Photos", comment: ""), message: NSLocalizedString("You have Denied access to Photos for Memories. In order for Memories to work you must enable this access in Settings. Would you like to do this now?", comment: ""), preferredStyle: .alert)
            let settings = UIAlertAction(title: NSLocalizedString("Settings", comment: ""), style: .default, handler: { (action) -> Void in
                let url = URL(string: UIApplicationOpenSettingsURLString)
                UIApplication.shared.openURL(url!);
            })
            let nothanks = UIAlertAction(title: NSLocalizedString("No thanks", comment: ""), style: .cancel, handler: { (action) -> Void in
                
            })
            alert.addAction(nothanks)
            alert.addAction(settings)
            
            UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }
}
