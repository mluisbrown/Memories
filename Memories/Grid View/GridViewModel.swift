//
//  GridViewModel.swift
//  Memories
//
//  Created by Michael Brown on 16/07/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import Foundation
import Photos
import PHAssetHelper
import ReactiveSwift
import Result


struct SectionChanges {
    let section: Int
    let nonIncremental: Bool
    let removed: [IndexPath]
    let inserted: [IndexPath]
    let changed: [IndexPath]
    let newItemCount: Int
    
    init(section: Int, removed: [IndexPath] = [], inserted: [IndexPath] = [], changed: [IndexPath] = [], newItemCount: Int = 0) {
        self.section = section
        self.nonIncremental = removed.count == 0 && inserted.count == 0 && changed.count == 0
        self.removed = removed
        self.inserted = inserted
        self.changed = changed
        self.newItemCount = newItemCount
    }
}

struct GridViewModel {
    enum Status: String {
        case none = ""
        case noAccess = "No access to Photo Library :("
        case loading = "Loading..."
        case noPhotos = "Sorry, no photos for this date :("
    }
    
    private let token = Lifetime.Token()
    // If the size is too large then PhotoKit doesn't return an optimal image size
    // see rdar://25181601 (https://openradar.appspot.com/radar?id=6158824289337344)
    private let gridThumbnailSize = CGSize(width: 256, height: 256)
    private let timeFormatter = DateComponentsFormatter()
    
    private let assetHelper = PHAssetHelper()
    private let dateFormatter = DateFormatter().with {
        $0.dateFormat = "MMMM dd"
    }
    
    private let assetFetchResults = MutableProperty([PHFetchResult<PHAsset>]())
    private let sectionChangesObserver: Signal<SectionChanges, NoError>.Observer
    let sectionChanged: Signal<SectionChanges, NoError>

    let libraryObserver: PhotoLibraryObserver?
    let imageManager: PHCachingImageManager?
    let photosAllowed: Bool
    let date = MutableProperty(Date())
    let resultsDate = MutableProperty(Date())
    let title = MutableProperty("Memories")
    private let status = MutableProperty<Status>(.noAccess)
    var statusText: Property<String> {
        return Property(status.map { return $0.rawValue } )
    }
    
    var sectionCount : Int {
        get {
            return assetFetchResults.value.count
        }
    }
    
    init(photosAllowed: Bool = false, libraryObserver: PhotoLibraryObserver? = nil, imageManager: PHCachingImageManager? = nil) {
        self.photosAllowed = photosAllowed
        self.libraryObserver = libraryObserver
        self.imageManager = imageManager

        (sectionChanged, sectionChangesObserver) = Signal<SectionChanges, NoError>.pipe()
        createBindings()
    }
    
    private func registerObservers() {
        NotificationCenter.default.reactive
            .notifications(forName: NSNotification.Name(PHAssetHelper.sourceTypesChangedNotification))
            .take(during: Lifetime(token))
            .observeValues { _ in
                // make a non-significant change to the date to force a reload of fetch results
                self.date.value = self.date.value.addingTimeInterval(60)
        }
        
        NotificationCenter.default.reactive
            .notifications(forName: NSNotification.Name.UIApplicationDidBecomeActive)
            .take(during: Lifetime(token))
            .observeValues { _ in
                if let date = NotificationManager.launchDate() {
                    self.date.value = date
                }
                self.promptForReview()
        }
    }
    
    private func createBindings() {
        if photosAllowed {
            registerObservers()
        }

        if let libraryObserver = libraryObserver {
            libraryObserver.signal
                .observeValues {
                    self.handleChange($0)
            }
        }
        
        date.signal.observeValues { date in
            self.assetFetchResults <~ self.updateFetchResults(for: date)
            self.status.value = .loading
            self.title.value = self.dateFormatter.string(from: date).uppercased() + " ▾" // ▼
        }

        assetFetchResults.signal.observeValues { fetchResults in
            self.status.value = fetchResults.count > 0 ? .none : .noPhotos
            self.resultsDate.value = self.date.value
        }
    }
    
    private func updateFetchResults(for date: Date) -> SignalProducer<[PHFetchResult<PHAsset>], NoError> {
        return SignalProducer<[PHFetchResult<PHAsset>], NoError> { observer, _ in
            observer.send(value: self.assetHelper.fetchResultsForAllYears(with: date))
            observer.sendCompleted()
        }
        .start(on: QueueScheduler(qos: .userInitiated))
    }
    
    private func handleChange(_ changeInstance: PHChange) {
        var cacheNeedsReset = false
        
        for section in (0 ..< sectionCount).reversed() {
            if let fetchResult = fetchResult(for: section),
                let changes = changeInstance.changeDetails(for: fetchResult) {
                let newFetchResult = changes.fetchResultAfterChanges
                
                if newFetchResult.count == 0 {
                    assetFetchResults.value.remove(at: section)
                } else {
                    assetFetchResults.value[section] = newFetchResult
                }
                
                let sectionChanges: SectionChanges
                if !changes.hasIncrementalChanges || changes.hasMoves {
                    sectionChanges = SectionChanges(section: section, newItemCount: newFetchResult.count)
                } else {
                    sectionChanges = SectionChanges(section: section,
                                                    removed: changes.removedIndexes?.indexPathsFromIndexes(in: section) ?? [],
                                                    inserted: changes.insertedIndexes?.indexPathsFromIndexes(in: section) ?? [],
                                                    changed: changes.changedIndexes?.indexPathsFromIndexes(in: section) ?? [],
                                                    newItemCount: newFetchResult.count)
                }
                
                sectionChangesObserver.send(value: sectionChanges)
                cacheNeedsReset = true
            }
        }
        
        if (cacheNeedsReset) {
            assetHelper.refreshDatesMapCache()
        }
    }
    
    // MARK: - API
    func goToNextDay() {
        date.value = date.value.nextDay()
    }

    func goToPreviousDay() {
        date.value = date.value.previousDay()
    }
    
    func asset(at indexPath : IndexPath) -> PHAsset? {
        guard (indexPath as NSIndexPath).section < assetFetchResults.value.count &&
            (indexPath as NSIndexPath).item < assetFetchResults.value[(indexPath as NSIndexPath).section].count else {
            return nil
        }
        
        return assetFetchResults.value[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).item] as PHAsset?
    }
    
    func numberOfItems(in section : Int) -> Int {
        guard section < assetFetchResults.value.count else {
            return 0
        }
        
        return assetFetchResults.value[section].count
    }
    
    func year(for section : Int) -> Int {
        guard section < assetFetchResults.value.count else {
            return 0
        }
        
        let asset = assetFetchResults.value[section].firstObject!
        let creationDate = asset.creationDate!
        
        return creationDate.year
    }
    
    func fetchResult(for section : Int) -> PHFetchResult<PHAsset>? {
        guard section < assetFetchResults.value.count else {
            return nil
        }
        return assetFetchResults.value[section]
    }
    
    func photoViewModel(for indexPath: IndexPath) -> PhotosViewModel {
        var assets : [PHAsset] = [PHAsset]()
        var selectedIndex = 0
        var currentIndex = 0
        
        for (section, fetchResult) in assetFetchResults.value.enumerated() {
            fetchResult.enumerateObjects({ (asset, index, stop) -> Void in
                assets.append(asset)
                if (section == (indexPath as NSIndexPath).section && index == (indexPath as NSIndexPath).item) {
                    selectedIndex = currentIndex
                }
                currentIndex += 1
            })
        }            
        
        return PhotosViewModel(assets: assets,
                               currentIndex: selectedIndex,
                               libraryObserver: libraryObserver!)
    }
    
    func indexPath(for selectedIndex: Int) -> IndexPath {
        var sectionTotal = 0
        
        for (section, fetchResult) in assetFetchResults.value.enumerated() {
            if sectionTotal + fetchResult.count > selectedIndex {
                return IndexPath(item: selectedIndex - sectionTotal, section: section)
            }
            sectionTotal += fetchResult.count
        }
        
        return IndexPath()
    }    
}

extension GridViewModel {
    private func promptForReview() {
        guard photosAllowed else { return }
        
        UpgradeManager.maybePromptForReview()
    }
}

// MARK: - Image Mangaer

extension GridViewModel {
    func startCachingImages(for assets: [PHAsset]) {
        imageManager?.startCachingImages(for: assets, targetSize: gridThumbnailSize, contentMode: .aspectFill, options: nil)
    }
    
    func stopCachingImages(for assets: [PHAsset]) {
        imageManager?.stopCachingImages(for: assets, targetSize: gridThumbnailSize, contentMode: .aspectFill, options: nil)
    }

    func stopCachingAllImages() {
        imageManager?.stopCachingImagesForAllAssets()
    }
    
    func loadCellData(for indexPath: IndexPath) -> SignalProducer<(UIImage?, String), NoError> {
        return SignalProducer<(UIImage?, String), NoError> { observer, _ in
            
            if let asset = self.asset(at: indexPath) {
                let durationText = asset.mediaType == .video ? " \(self.timeFormatter.videoDuration(from: asset.duration) ?? "") " : ""
                self.imageManager?.requestImage(for: asset, targetSize: self.gridThumbnailSize, contentMode: .aspectFill, options: nil) {
                    result, info in

                    guard let image = result else {
                        return
                    }
                    
                    observer.send(value: (image, durationText))
                    
                    let isDegraded = ((info?[PHImageResultIsDegradedKey] as? NSNumber) as? Bool) ?? true
                    if !isDegraded {
                        observer.sendCompleted()
                    }
                }
            }
            else {
                observer.send(value: (nil, ""))
                observer.sendCompleted()
            }
        }
    }
}
