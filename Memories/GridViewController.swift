//
//  GridViewController.swift
//  Memories
//
//  Created by Michael Brown on 18/06/2015.
//  Copyright (c) 2015 Michael Brown. All rights reserved.
//

import UIKit
import Photos

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

class GridViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, PHPhotoLibraryChangeObserver {
    let reuseIdentifier = "PhotoCell"
    let headerIdentifier = "YearHeader"
    var gridThumbnailSize : CGSize = CGSizeZero
    
    var model : GridViewModel!

    var imageManager : PHCachingImageManager!
    var previousPreheatRect : CGRect = CGRectZero
    var cellSize : CGSize = CGSizeZero

    deinit {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        imageManager = PHCachingImageManager()
        
#if (arch(i386) || arch(x86_64)) && os(iOS)
        model = GridViewModel(/*date: NSDate()*/)
#else
        model = GridViewModel(date: NSDate())
#endif
    
        
        resetCachedAssets()
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self);
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        configureCellSizeForViewSize(view.bounds.size)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        updateCachedAssets()
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        configureCellSizeForViewSize(size)
        updateCachedAssets()
        
        coordinator.animateAlongsideTransition({ (context : UIViewControllerTransitionCoordinatorContext) -> Void in
            self.collectionView?.performBatchUpdates(nil, completion: nil)
        }, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        guard segue.identifier != nil && segue.identifier! == "photos" else {
            return;
        }
        
        let indexPath = collectionView?.indexPathForCell(sender as! UICollectionViewCell)
        
        let photoViewController = segue.destinationViewController as! PhotoViewController
        photoViewController.model = model.photoViewModelForIndexPath(indexPath!)
    }

    // MARK: UICollectionViewDataSource

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
        
        if let asset = model.assetAtIndexPath(indexPath) {
            imageManager.requestImageForAsset(asset, targetSize: gridThumbnailSize, contentMode: .AspectFill, options: nil) { (result : UIImage?, info : [NSObject : AnyObject]?) -> Void in
                // Only update the thumbnail if the cell tag hasn't changed. Otherwise, the cell has been re-used.
                if cell.tag == currentTag {
                    cell.thumbnailImage = result
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
    
    // MARK: UICollectionViewDelegateFlowLayout
    
    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
            return cellSize
    }
    
    // MARK: UIScrollViewDelegate
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        updateCachedAssets()
    }
    
    // MARK: PHPhotoLibraryChangeObserver

    func photoLibraryDidChange(changeInstance: PHChange) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            var cacheNeedsReset = false
            
            for section in 0..<self.model.sectionCount {
                if let collectionChanges = changeInstance.changeDetailsForFetchResult(self.model.fetchResultForSection(section)!) {
                    // get the new fetch result
                    self.model.setFetchResultForSection(section, fetchResult: collectionChanges.fetchResultAfterChanges)
                    
                    if (!collectionChanges.hasIncrementalChanges || collectionChanges.hasMoves) {
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
                            if let changedIndexes = collectionChanges.insertedIndexes {
                                if (changedIndexes.count != 0) {
                                    self.collectionView?.reloadItemsAtIndexPaths(changedIndexes.indexPathsFromIndexesInSection(section))
                                }
                            }
                            }, completion: nil)
                    }
                    
                    cacheNeedsReset = true
                }
            }
            
            if (cacheNeedsReset) {
                self.resetCachedAssets()
            }
        }
    }

    // MARK: Asset Caching
    
    func resetCachedAssets() {
        imageManager.stopCachingImagesForAllAssets()
        previousPreheatRect = CGRectZero
    }

    func updateCachedAssets() {
        guard self.isViewLoaded() && self.view.window != nil else {
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
        return indexPaths.map() {
            self.model.assetAtIndexPath($0)!
        }
    }
    
    // MARK: Helpers
    
    func configureCellSizeForViewSize(viewSize : CGSize) {
        let MIN_WIDTH = CGFloat(90.0)
        let viewWidth = viewSize.width
        let cellsPerRow = floor(viewWidth / MIN_WIDTH)
        let cellWidth = floor((viewWidth  - (cellsPerRow - 1)) / cellsPerRow)
        
        let cellSize = CGSizeMake(cellWidth, cellWidth)
        self.cellSize = cellSize
        
        let scale = UIScreen.mainScreen().scale
        gridThumbnailSize = CGSizeMake(cellSize.width * scale, cellSize.height * scale)
    }
}
