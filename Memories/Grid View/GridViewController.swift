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
    
    var model : GridViewModel! {
        didSet {
            bindToModel()
        }
    }

    var statusBarVisible = true
    
    var previousPreheatRect : CGRect = .zero
    var cellSize : CGSize = .zero
    
    let titleView = UILabel().with {
        $0.backgroundColor = UIColor.clear
        $0.font = UIFont.systemFont(ofSize: 16)
        $0.textColor = UIColor.white
        $0.isUserInteractionEnabled = true
        $0.textAlignment = .center
    }
    
    let statusLabel = UILabel().with {
        $0.backgroundColor = UIColor.clear
        $0.font = UIFont.systemFont(ofSize: 16)
        $0.textColor = UIColor.white
    }
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    var topPullView : PullView? = nil
    var bottomPullView : PullView? = nil
    var shouldReload = false
    var reloadNext = false

    let RELEASE_THRESHOLD : CGFloat = 100.0
    
    private func bindToModel() {
        model.resultsDate.signal.observe(on: QueueScheduler.main)
            .skipRepeats(==)
            .observeValues { [weak self] date in
                self?.refreshData(for: date)
        }
        
        model.title.producer.observe(on: QueueScheduler.main)
            .startWithValues { [weak self] title in
                self?.titleView.text = title
                self?.titleView.sizeToFit()
        }
        
        model.sectionChanged.observe(on: QueueScheduler.main)
            .observeValues { [weak self]  changes in
                self?.updateSection(with: changes)
        }
        
        model.statusText.producer.observe(on: QueueScheduler.main)
            .startWithValues { [weak self] status in
                self?.showHideStatusLabel(status)
        }
    }
    
    private func loadPhotos() {
        PhotoLibraryAuthorization.checkPhotosPermission().observe(on: QueueScheduler.main)
            .startWithValues { [weak self] status in
                switch status {
                case .authorized:
                    self?.model = GridViewModel(photosAllowed: true,
                                                libraryObserver: PhotoLibraryObserver(library: PHPhotoLibrary.shared()),
                                                imageManager: PHCachingImageManager())
            
                    let startDate = Date()
                    if let date = NotificationManager.launchDate() {
                        self?.model.date.value = date
                    } else {
                        self?.model.date.value = startDate
                    }

                case .denied, .restricted, .notDetermined:
                    break
                }
        }
    }
    
    private func configureTitleView() {
        navigationItem.titleView = titleView
        
        let tgr = UITapGestureRecognizer(target: self, action: #selector(GridViewController.titleTapped(_:)))
        titleView.addGestureRecognizer(tgr)
    }
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTitleView()
        
        model = GridViewModel()
        loadPhotos()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureCellSize(for: view.bounds.size)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateCachedAssets()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        configureCellSize(for: size)
        updateCachedAssets()
        
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView?.performBatchUpdates(nil, completion: nil)
        }, completion: { _ in
            self.adjustPullViewPositions()
        })
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        
        let largeScreen = newCollection.verticalSizeClass == .regular &&
                        newCollection.horizontalSizeClass == .regular
        let contentMode: UIViewContentMode = largeScreen ? .scaleAspectFit : .scaleAspectFill
        
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView?.visibleCells.forEach {
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
    private func updateSection(with changes: SectionChanges) {
        if changes.nonIncremental {
            collectionView?.reloadSections(IndexSet(integer: changes.section))
        }
        else {
            collectionView?.performBatchUpdates({
                guard changes.newItemCount > 0 else {
                    self.collectionView?.deleteSections(IndexSet(integer: changes.section))
                    return
                }

                self.collectionView?.deleteItems(at: changes.removed)
                self.collectionView?.insertItems(at: changes.inserted)
                self.collectionView?.reloadItems(at: changes.changed)
            }, completion: nil)
        }
        
        resetCachedAssets()
    }
    
    private func refreshData(for date: Date) {
        resetCachedAssets()
        collectionView?.reloadData()
        collectionView?.setContentOffset(CGPoint(x: 0, y: -collectionView!.contentInset.top), animated: false)
        
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
        if let photosViewController = storyboard?.instantiateViewController(withIdentifier: "photosViewController") as? PhotosViewController {
            photosViewController.model = model.photoViewModel(for: indexPath)
            photosViewController.delegate = self
            if let cell = collectionView.cellForItem(at: indexPath) as? GridViewCell, let imageView = cell.imageView {
                photosViewController.presentTransition = PhotosViewPresentTransition(sourceImageView: imageView)
                photosViewController.transitioningDelegate = photosViewController
                photosViewController.modalPresentationStyle = .custom
                
                present(photosViewController, animated: true, completion: nil)
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
        
        model.loadCellData(for: indexPath)
            .observe(on: UIScheduler())
            .startWithValues {
            if cell.tag == currentTag {
                // Only update the thumbnail if the cell tag hasn't changed. Otherwise, the cell has been re-used.
                cell.imageView?.image = $0.0
                cell.durationLabel?.text = $0.1
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

// MARK: - PhotosViewControllerDelegate
extension GridViewController: PhotosViewControllerDelegate {
    func setCurrent(index: Int) {
        collectionView?.scrollToItem(at: model.indexPath(for: index), at: .centeredVertically, animated: false)
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
            shouldReload = false
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
            
            collectionView?.addSubview(topPullView!)
            collectionView?.addSubview(bottomPullView!)
        }
    }
    
    func adjustPullViewPositions() {
        guard let tpv = topPullView,
            let bpv = bottomPullView,
            let collectionView = collectionView else {
            return
        }
        
        let topOffset = topLayoutGuide.length
        
        let resizeView = { (view: PullView, yPosition: CGFloat, viewHeight: CGFloat) -> Void in
            view.frame = CGRect(x: 0, y: yPosition, width: collectionView.frame.width, height: viewHeight)
            view.alpha = pow(fabs(viewHeight), 2) / pow(self.RELEASE_THRESHOLD, 2)
            view.willRelease = fabs(viewHeight) >= self.RELEASE_THRESHOLD
        }
        
        // handle top pull view
        if collectionView.contentOffset.y <= -topOffset {
            let viewHeight = topOffset + collectionView.contentOffset.y
            resizeView(tpv, 0, viewHeight)
        } else if tpv.frame.height > 0 {
            tpv.frame = CGRect(x: 0, y: 0, width: collectionView.frame.width, height: 0)
        }
        
        // handle bottom pull view
        let offset = collectionView.contentOffset.y
        let boundsHeight = collectionView.bounds.height
        let sizeHeight = collectionView.contentSize.height
        let bottomOfView = max(sizeHeight, boundsHeight - topOffset)
        let y = offset + boundsHeight;
        
        if y >= bottomOfView {
            let viewHeight = y - bottomOfView
            let yPosition = bottomOfView
            
            resizeView(bpv, yPosition, viewHeight)
        } else if bpv.frame.height > 0 {
            bpv.frame = CGRect(x: 0, y: 0, width: collectionView.frame.width, height: 0)
        }
    }
}


// MARK: - Asset Caching
extension GridViewController {
    fileprivate func resetCachedAssets() {
        model.stopCachingAllImages()
        previousPreheatRect = CGRect.zero
    }
    
    fileprivate func updateCachedAssets() {
        guard let _ = view.window,
            let collectionView = collectionView,
            model.photosAllowed,
            isViewLoaded else {
                return
        }
        
        // The preheat window is twice the height of the visible rect
        let bounds = collectionView.bounds;
        let preheatRect = bounds.insetBy(dx: 0.0, dy: -0.5 * bounds.height);
        
        // If scrolled by a "reasonable" amount...
        let delta = abs(preheatRect.midY - previousPreheatRect.midY);
        if delta > bounds.height / 3.0 {
            var addedIndexPaths = [IndexPath]()
            var removedIndexPaths = [IndexPath]()
            
            computeDifferenceBetweenRects(previousPreheatRect, preheatRect,
                                          removedHandler: {
                                            removedIndexPaths += collectionView.indexPathsForElements(in: $0)
            },
                                          addedHandler: {
                                            addedIndexPaths += collectionView.indexPathsForElements(in: $0)
            })
            
            let assetsToStartCaching = assets(at: addedIndexPaths)
            let assetsToStopCaching = assets(at: removedIndexPaths)
            
            model.startCachingImages(for: assetsToStartCaching)
            model.stopCachingImages(for: assetsToStopCaching)
            
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
    
    fileprivate func showHideStatusLabel(_ text: String) {
        // make sure views have been layed out properly
        guard topLayoutGuide.length != 0 else {
            return
        }
        
        statusLabel.text = text
        
        guard !text.isEmpty else {
            statusLabel.removeFromSuperview()
            return
        }
        
        if statusLabel.superview == nil {
            collectionView?.addSubview(statusLabel)
            
            constrain(statusLabel, collectionView!) { noPhotosLabel, collectionView in
                noPhotosLabel.centerX == collectionView.centerX
                noPhotosLabel.centerY == collectionView.centerY - topLayoutGuide.length
            }
        }
    }
}

