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

extension NSIndexSet {
    func indexPathsFromIndexesInSection(section : Int) -> [NSIndexPath] {
        var indexPaths = [NSIndexPath]()
        
        self.enumerateIndexesUsingBlock() {index, stop in
            indexPaths.append(NSIndexPath(forItem: index, inSection: section))
        }
        
        return indexPaths
    }
}

extension UICollectionView {
    func indexPathsForElementsInRect(rect : CGRect) -> [NSIndexPath] {
        if let allLayoutAttributes = self.collectionViewLayout.layoutAttributesForElementsInRect(rect) {
            return allLayoutAttributes.map() {$0.indexPath}
        }
        
        return [NSIndexPath]()
    }
}

class GridViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, PHPhotoLibraryChangeObserver, UIPopoverPresentationControllerDelegate {
    let reuseIdentifier = "PhotoCell"
    let headerIdentifier = "YearHeader"
    // If the size is too large then PhotoKit doesn't return an optimal image size
    // see rdar://25181601 (https://openradar.appspot.com/radar?id=6158824289337344)
    let gridThumbnailSize = CGSize(width: 256, height: 256)
    
    var model : GridViewModel!

    var titleView : UILabel!
    
    var imageManager : PHCachingImageManager!
    var previousPreheatRect : CGRect = .zero
    var cellSize : CGSize = .zero
    var photosAllowed = false
    
    let noPhotosLabel : UILabel
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .Dark))
    
    var topPullView : PullView? = nil
    var bottomPullView : PullView? = nil
    var shouldReload = false
    var reloadNext = false

    let RELEASE_THRESHOLD : CGFloat = 100.0
    let dateFormatter = NSDateFormatter()
    let assetHelper = PHAssetHelper()
    
    required init?(coder aDecoder: NSCoder) {
        noPhotosLabel = UILabel()
        noPhotosLabel.backgroundColor = UIColor.clearColor()
        noPhotosLabel.font = UIFont.systemFontOfSize(16)
        noPhotosLabel.textColor = UIColor.whiteColor()
        
        super.init(coder: aDecoder)
    }
    
    deinit {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: - UIView
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dateFormatter.dateFormat = "MMMM dd"
        model = GridViewModel() { [weak self] date in
            guard let `self` = self else { return }
            self.resetCachedAssets()
            self.collectionView?.reloadData()
            self.collectionView!.setContentOffset(CGPointMake(0, -self.collectionView!.contentInset.top), animated: false)
            self.showHideNoPhotosLabel()
            
            self.createOrUpdatePullViews(date)
            self.title = self.dateFormatter.stringFromDate(date).uppercaseString + " ▾" // ▼
            self.showHideBlur(false)
        }
        
        checkPhotosPermission {
            self.photosAllowed = true
            self.imageManager = PHCachingImageManager()
            
            let startDate = NSDate()
            if let date = NotificationManager.launchDate() {
                self.model.date.value = date
            } else {
                self.model.date.value = startDate
            }
            
            PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self);
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(GridViewController.appDidBecomeActive),
                name: UIApplicationDidBecomeActiveNotification, object: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(GridViewController.reloadPhotos),
                name: PHAssetHelper.sourceTypesChangedNotification, object: nil)
        }
    }

    override var title: String? {
        set {
            super.title = newValue
            
            let titleView : UILabel!
            if let aTitleView : UILabel = self.navigationItem.titleView as? UILabel  {
                titleView = aTitleView;
            } else {
                titleView = UILabel(frame: CGRectZero);
                	titleView.backgroundColor = UIColor.clearColor()
                titleView.font = UIFont.systemFontOfSize(16)
                titleView.textColor = UIColor.whiteColor()
                titleView.userInteractionEnabled = true
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
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        configureCellSizeForViewSize(view.bounds.size)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        updateCachedAssets()
        
        guard noPhotosLabel.text == nil else { return }
        showHideNoPhotosLabel(NSLocalizedString("Loading...", comment: ""))
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        configureCellSizeForViewSize(size)
        updateCachedAssets()
        
        coordinator.animateAlongsideTransition({ (context : UIViewControllerTransitionCoordinatorContext) -> Void in
            self.collectionView?.performBatchUpdates(nil, completion: nil)
            }, completion: {(context : UIViewControllerTransitionCoordinatorContext) -> Void in
                self.adjustPullViewPositions()
            })
    }
    
    override func willTransitionToTraitCollection(newCollection: UITraitCollection, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        let largeScreen = newCollection.verticalSizeClass == .Regular &&
                        newCollection.horizontalSizeClass == .Regular
        let contentMode: UIViewContentMode = largeScreen ? .ScaleAspectFit : .ScaleAspectFill
        
        coordinator.animateAlongsideTransition({ (context : UIViewControllerTransitionCoordinatorContext) -> Void in
            self.collectionView!.visibleCells().forEach {
                let gridCell = $0 as! GridViewCell
                gridCell.imageView?.contentMode = contentMode
            }
            }, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Notification handlers
    func appDidBecomeActive() {
        if let date = NotificationManager.launchDate() where self.photosAllowed {
            self.model.date.value = date
        }
    }
    
    func reloadPhotos() {
        // force the date change to fire, but
        // with the same date, to reload the data
        model.date.value = model.date.value
    }

    // MARK: - Actions
    func titleTapped(tgr: UITapGestureRecognizer) {
        let sourceView = tgr.view!
        
        if let datePickerVC = storyboard?.instantiateViewControllerWithIdentifier("datePicker") as? DatePickerViewController {
            datePickerVC.modalPresentationStyle = UIModalPresentationStyle.Popover
            datePickerVC.preferredContentSize = CGSizeMake(200, 240)
            
            if let popoverPresentationController = datePickerVC.popoverPresentationController {
                popoverPresentationController.sourceView = sourceView
                popoverPresentationController.sourceRect = CGRectMake(0, 0, sourceView.frame.size.width, sourceView.frame.size.height)
                popoverPresentationController.delegate = self
                popoverPresentationController.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.2)
            }
            
            datePickerVC.initialDate = model.date.value
            presentViewController(datePickerVC, animated: true, completion: nil)
        }
    }
    
    
    // MARK: - UIPopoverPresentationControllerDelegate
    func popoverPresentationControllerShouldDismissPopover(popoverPresentationController: UIPopoverPresentationController) -> Bool {
        return true
    }

    func popoverPresentationControllerDidDismissPopover(popoverPresentationController: UIPopoverPresentationController) {
        let datePickerVC = popoverPresentationController.presentedViewController as! DatePickerViewController
        
        if let selectedDate = datePickerVC.selectedDate where !selectedDate.isEqualToDate(model.date.value) {
            model.date.value = datePickerVC.selectedDate!
        }        
    }
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.None
    }
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.None
    }
    
    // MARK: - UICollectionViewDelegate
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if let photoViewController = storyboard?.instantiateViewControllerWithIdentifier("photoViewController") as? PhotoViewController {
            photoViewController.model = model.photoViewModelForIndexPath(indexPath)
            if let cell = collectionView.cellForItemAtIndexPath(indexPath) as? GridViewCell, imageView = cell.imageView {
                photoViewController.presentTransition = PhotoViewPresentTransition(sourceImageView: imageView)
                photoViewController.transitioningDelegate = photoViewController
                photoViewController.modalPresentationStyle = .Custom
                
                presentViewController(photoViewController, animated: true, completion: nil)
            }
        }
    }
    
    func setSelectedIndex(index: Int) {
        collectionView?.selectItemAtIndexPath(model.indexPathForSelectedIndex(index), animated: false, scrollPosition: .CenteredVertically)
    }
    
    func imageViewForIndex(index: Int) -> UIImageView? {
        guard let cell = collectionView?.cellForItemAtIndexPath(model.indexPathForSelectedIndex(index)) as? GridViewCell else {
            return nil
        }
        
        return cell.imageView
    }
    
    // MARK: - UICollectionViewDataSource

    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return model.sectionCount
    }


    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return model.numberOfItemsInSection(section)
    }

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! GridViewCell
    
        // Increment the cell's tag
        let currentTag = cell.tag + 1
        cell.tag = currentTag
        
        cell.imageView?.contentMode = thumbnailContentMode
        
        if let asset = model.assetAtIndexPath(indexPath) {
            imageManager.requestImageForAsset(asset, targetSize: gridThumbnailSize, contentMode: .AspectFill, options: nil) { (result : UIImage?, info : [NSObject : AnyObject]?) -> Void in
                if let image = result where cell.tag == currentTag {
                    // Only update the thumbnail if the cell tag hasn't changed. Otherwise, the cell has been re-used.
                    cell.thumbnailImage = image
                }
            }
        }
    
        return cell
    }

    override func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        let headerView = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: headerIdentifier, forIndexPath: indexPath) as! GridHeaderView
        headerView.label.text = String(model.yearForSection(indexPath.section))
        
        return headerView
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
            return cellSize
    }
    
    
    // MARK: - UIScrollViewDelegate
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        updateCachedAssets()
        adjustPullViewPositions()
    }
    
    override func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard let tpv = topPullView, bpv = bottomPullView where decelerate else {
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
    
    override func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        if shouldReload {
            if reloadNext {
                model.goToNextDay()
            } else {
                model.goToPreviousDay()
            }
        }
    }
    
    // MARK: - Scroll to Change Date
    
    func createOrUpdatePullViews(date: NSDate) {
        if let tpv = topPullView, bpv = bottomPullView {
            tpv.date = date.previousDay()
            bpv.date = date.nextDay()
        } else {
            topPullView = PullView(frame: CGRectMake(0, 0, collectionView!.frame.width, 0), date: date.previousDay())
            bottomPullView = PullView(frame: CGRectMake(0, 0, collectionView!.frame.width, 0), date: date.nextDay())
            
            collectionView!.addSubview(topPullView!)
            collectionView!.addSubview(bottomPullView!)
        }
    }
    
    func adjustPullViewPositions() {
        guard let tpv = topPullView, bpv = bottomPullView else {
            return
        }
        
        let topOffset = topLayoutGuide.length
        
        let resizeView = {(view: PullView, yPosition: CGFloat, viewHeight: CGFloat) -> Void in
            view.frame = CGRectMake(0, yPosition, self.collectionView!.frame.width, viewHeight)
            view.alpha = pow(fabs(viewHeight), 2) / pow(self.RELEASE_THRESHOLD, 2)
            view.willRelease = fabs(viewHeight) >= self.RELEASE_THRESHOLD
        }
        
        // handle top pull view
        if collectionView!.contentOffset.y <= -topOffset {
            let viewHeight = topOffset + collectionView!.contentOffset.y
            resizeView(tpv, 0, viewHeight)
        } else if tpv.frame.height > 0 {
            tpv.frame = CGRectMake(0, 0, collectionView!.frame.width, 0)
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
            bpv.frame = CGRectMake(0, 0, collectionView!.frame.width, 0)
        }
    }
    
    // MARK: - PHPhotoLibraryChangeObserver

    func photoLibraryDidChange(changeInstance: PHChange) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            var cacheNeedsReset = false
            
            for section in (0..<self.model.sectionCount).reverse() {
                if let fetchResult = self.model.fetchResultForSection(section),
                    collectionChanges = changeInstance.changeDetailsForFetchResult(fetchResult) {
                    // get the new fetch result
                    self.model.setFetchResultForSection(section, fetchResult: collectionChanges.fetchResultAfterChanges)
                    
                    if !collectionChanges.hasIncrementalChanges || collectionChanges.hasMoves {
                        self.collectionView?.reloadData()
                    } else {
                        self.collectionView?.performBatchUpdates({
                            if let removedIndexes = collectionChanges.removedIndexes {
                                if (removedIndexes.count != 0) {
                                    self.collectionView?.deleteItemsAtIndexPaths(removedIndexes.indexPathsFromIndexesInSection(section))
                                }
                            }
                            if let insertedIndexes = collectionChanges.insertedIndexes {
                                if (insertedIndexes.count != 0) {
                                    self.collectionView?.insertItemsAtIndexPaths(insertedIndexes.indexPathsFromIndexesInSection(section))
                                }
                            }
                            if let changedIndexes = collectionChanges.changedIndexes {
                                if (changedIndexes.count != 0) {
                                    self.collectionView?.reloadItemsAtIndexPaths(changedIndexes.indexPathsFromIndexesInSection(section))
                                }
                            }
                            if collectionChanges.fetchResultAfterChanges.count == 0 {
                                self.collectionView?.deleteSections(NSIndexSet(index: section))
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
        previousPreheatRect = CGRectZero
    }

    func updateCachedAssets() {
        guard isViewLoaded() && view.window != nil && imageManager != nil else {
            return
        }
        
        // The preheat window is twice the height of the visible rect
        let bounds = collectionView!.bounds;
        let preheatRect = CGRectInset(bounds, 0.0, -0.5 * CGRectGetHeight(bounds));
        
        // If scrolled by a "reasonable" amount...
        let delta = abs(CGRectGetMidY(preheatRect) - CGRectGetMidY(previousPreheatRect));
        if delta > CGRectGetHeight(bounds) / 3.0 {
            var addedIndexPaths = [NSIndexPath]()
            var removedIndexPaths = [NSIndexPath]()
            
            computeDifferenceBetweenRects(previousPreheatRect, preheatRect,
                removedHandler: {
                    removedIndexPaths += self.collectionView!.indexPathsForElementsInRect($0)
                },
                addedHandler: {
                    addedIndexPaths += self.collectionView!.indexPathsForElementsInRect($0)
                })
            
            let assetsToStartCaching = assetsAtIndexPaths(addedIndexPaths)
            let assetsToStopCaching = assetsAtIndexPaths(removedIndexPaths)
            
            imageManager.startCachingImagesForAssets(assetsToStartCaching, targetSize: gridThumbnailSize, contentMode: .AspectFill, options: nil)
            imageManager.stopCachingImagesForAssets(assetsToStopCaching, targetSize: gridThumbnailSize, contentMode: .AspectFill, options: nil)

            previousPreheatRect = preheatRect
        }
    }

    func computeDifferenceBetweenRects(oldRect: CGRect, _ newRect: CGRect, removedHandler: (CGRect) -> (), addedHandler: (CGRect) -> ()) {
        if CGRectIntersectsRect(newRect, oldRect) {
            let oldMaxY = CGRectGetMaxY(oldRect)
            let oldMinY = CGRectGetMinY(oldRect)
            let newMaxY = CGRectGetMaxY(newRect)
            let newMinY = CGRectGetMinY(newRect)
            
            if newMaxY > oldMaxY {
                let rectToAdd = CGRectMake(newRect.origin.x, oldMaxY, newRect.size.width, (newMaxY - oldMaxY))
                addedHandler(rectToAdd)
            }
            if oldMinY > newMinY {
                let rectToAdd = CGRectMake(newRect.origin.x, newMinY, newRect.size.width, (oldMinY - newMinY))
                addedHandler(rectToAdd)
            }
            if newMaxY < oldMaxY {
                let rectToRemove = CGRectMake(newRect.origin.x, newMaxY, newRect.size.width, (oldMaxY - newMaxY))
                removedHandler(rectToRemove)
            }
            if oldMinY < newMinY {
                let rectToRemove = CGRectMake(newRect.origin.x, oldMinY, newRect.size.width, (newMinY - oldMinY))
                removedHandler(rectToRemove)
            }
        } else {
            addedHandler(newRect);
            removedHandler(oldRect);
        }
    }
    
    func assetsAtIndexPaths(indexPaths : [NSIndexPath]) -> [PHAsset] {
        return indexPaths.flatMap() {
            self.model.assetAtIndexPath($0)
        }        
    }
    
    // MARK: - Helpers
    func showHideBlur(show: Bool) {
        if show {
            let window = UIApplication.sharedApplication().keyWindow!
            var frame = window.frame
            frame.origin.y += topLayoutGuide.length
            
            blurView.frame = frame
            window.addSubview(blurView)
        } else {
            blurView.removeFromSuperview()
        }
    }
    
    
    func configureCellSizeForViewSize(viewSize : CGSize) {
        let MIN_WIDTH = CGFloat(90.0)
        let viewWidth = viewSize.width
        let maxCellsPerRow: CGFloat = viewSize.width < viewSize.height ? 5 : 7
        let cellsPerRow = min(floor(viewWidth / MIN_WIDTH), maxCellsPerRow)
        let cellWidth = floor((viewWidth  - (cellsPerRow - 1)) / cellsPerRow)
        
        let cellSize = CGSizeMake(cellWidth, cellWidth)
        self.cellSize = cellSize
    }
    
    func showHideNoPhotosLabel(text: String? = nil) {
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
    
    func checkPhotosPermission(handler : () -> ()) {
        let authStatus = PHPhotoLibrary.authorizationStatus();
        
        if authStatus == .Authorized {
            handler()
        }

        if authStatus == .NotDetermined {
            let alert = UIAlertController(title: NSLocalizedString("Let Memories access Photos?", comment: ""), message: NSLocalizedString("Memories can only work if it has access to your photos. If you tap 'Allow' iOS will ask your permission.", comment: ""), preferredStyle: .Alert)
            let allow = UIAlertAction(title: NSLocalizedString("Allow", comment: ""), style: .Default, handler: { (action) -> Void in
                PHPhotoLibrary.requestAuthorization({ (status) -> Void in
                    if status == .Authorized {
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            handler()
                        })
                    }
                })
            })
            let deny = UIAlertAction(title: NSLocalizedString("Not Now", comment: ""), style: .Cancel, handler: { (action) -> Void in
                
            })
            alert.addAction(deny)
            alert.addAction(allow)
            
            UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
            return
        }
        
        if authStatus == .Denied {
            let alert = UIAlertController(title: NSLocalizedString("No Access to Photos", comment: ""), message: NSLocalizedString("You have Denied access to Photos for Memories. In order for Memories to work you must enable this access in Settings. Would you like to do this now?", comment: ""), preferredStyle: .Alert)
            let settings = UIAlertAction(title: NSLocalizedString("Settings", comment: ""), style: .Default, handler: { (action) -> Void in
                let url = NSURL(string: UIApplicationOpenSettingsURLString)
                UIApplication.sharedApplication().openURL(url!);
            })
            let nothanks = UIAlertAction(title: NSLocalizedString("No thanks", comment: ""), style: .Cancel, handler: { (action) -> Void in
                
            })
            alert.addAction(nothanks)
            alert.addAction(settings)
            
            UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
        }
    }
}
