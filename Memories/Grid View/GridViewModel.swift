import Foundation
import UIKit
import Core
import Photos
import PHAssetHelper
import ReactiveSwift

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

class GridViewModel {
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
    private let sectionChangesObserver: Signal<SectionChanges, Never>.Observer
    let sectionChanged: Signal<SectionChanges, Never>

    private var libraryObserver: PhotoLibraryObserver? = nil {
        didSet {
            guard let observer = libraryObserver else { return }
            observer.signal.observeValues(self.handleChange(_:))
        }
    }
    private var imageManager: PHCachingImageManager? = nil
    private(set) var photosAllowed = false {
        didSet {
            if photosAllowed {
                registerObservers()
            }
        }
    }

    let date = MutableProperty(Date())

    private let resultsDateObserver: Signal<Date, Never>.Observer
    let resultsDate: Signal<Date, Never>

    private let title = MutableProperty(NSAttributedString(string: "Memories"))
    private let status = MutableProperty<Status>(.noAccess)
    let statusText: Property<String>
    let titleText: Property<NSAttributedString>

    var sectionCount : Int {
        return assetFetchResults.value.count
    }

    init() {
        (sectionChanged, sectionChangesObserver) = Signal<SectionChanges, Never>.pipe()
        (resultsDate, resultsDateObserver) = Signal<Date, Never>.pipe()
        statusText = Property(status.map { $0.rawValue } )
        titleText = Property(capturing: title)
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
            .notifications(forName: UIApplication.didBecomeActiveNotification)
            .take(during: Lifetime(token))
            .observeValues { _ in
                if let date = Current.notificationsController.launchDate() {
                    self.date.value = date
                }
                self.promptForReview()
            }
    }
    
    private func createBindings() {
        date.signal.observeValues { date in
            self.assetFetchResults <~ self.updateFetchResults(for: date)
            self.status.value = .loading

            let attachment = NSTextAttachment().with {
                $0.image = UIImage(systemName: "arrowtriangle.down.fill")?
                    .withTintColor(Current.colors.label)
            }
            let imageString = NSAttributedString(attachment: attachment)
            let dateString = NSMutableAttributedString(string: "\(self.dateFormatter.string(from: date).uppercased()) ")
            dateString.append(imageString)

            self.title.value = dateString
        }

        assetFetchResults.signal.observeValues { fetchResults in
            self.status.value = fetchResults.count > 0 ? .none : .noPhotos
            self.resultsDateObserver.send(value: self.date.value)
        }
    }
    
    private func updateFetchResults(for date: Date) -> SignalProducer<[PHFetchResult<PHAsset>], Never> {
        return SignalProducer<[PHFetchResult<PHAsset>], Never> { observer, _ in
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
                    sectionChanges = SectionChanges(
                        section: section,
                        newItemCount: newFetchResult.count
                    )
                } else {
                    sectionChanges = SectionChanges(
                        section: section,
                        removed: changes.removedIndexes?.indexPathsFromIndexes(in: section) ?? [],
                        inserted: changes.insertedIndexes?.indexPathsFromIndexes(in: section) ?? [],
                        changed: changes.changedIndexes?.indexPathsFromIndexes(in: section) ?? [],
                        newItemCount: newFetchResult.count
                    )
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
    func initialisePhotoLibrary() {
        PhotoLibraryAuthorization.checkPhotosPermission().observe(on: UIScheduler())
            .startWithValues { [weak self] status in
                switch status {
                case .authorized, .limited:
                    self?.photosAllowed = true
                    self?.libraryObserver = PhotoLibraryObserver(library: PHPhotoLibrary.shared())
                    self?.imageManager = PHCachingImageManager()

                    if let date = Current.notificationsController.launchDate() {
                        self?.date.value = date
                    } else {
                        self?.date.value = Date()
                    }

                case .denied, .restricted, .notDetermined:
                    break
                @unknown default:
                    break;
                }
            }
    }

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
        
        ReviewHelper.maybePromptForReview()
    }
}

// MARK: - Image Mangaer

extension GridViewModel {
    func startCachingImages(for indexPaths: [IndexPath]) {
        imageManager?.startCachingImages(
            for: indexPaths.compactMap(asset(at:)),
            targetSize: gridThumbnailSize,
            contentMode: .aspectFill,
            options: nil
        )
    }
    
    func stopCachingImages(for indexPaths: [IndexPath]) {
        imageManager?.stopCachingImages(
            for: indexPaths.compactMap(asset(at:)),
            targetSize: gridThumbnailSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    func stopCachingAllImages() {
        imageManager?.stopCachingImagesForAllAssets()
    }

    func loadCellData(for indexPath: IndexPath) -> SignalProducer<GridViewCellModel, Never> {
        return SignalProducer<GridViewCellModel, Never> { observer, _ in
            
            if let asset = self.asset(at: indexPath) {
                let durationText = asset.mediaType == .video ? " \(self.timeFormatter.videoDuration(from: asset.duration) ?? "") " : ""
                self.imageManager?.requestImage(for: asset, targetSize: self.gridThumbnailSize, contentMode: .aspectFill, options: nil) {
                    result, info in

                    guard let image = result else {
                        return
                    }
                    
                    observer.send(
                        value: GridViewCellModel(
                            assetID: asset.localIdentifier,
                            image: image,
                            durationText: durationText,
                            isFavourite: asset.isFavorite
                        )
                    )
                    
                    let isDegraded = ((info?[PHImageResultIsDegradedKey] as? NSNumber) as? Bool) ?? true
                    if !isDegraded {
                        observer.sendCompleted()
                    }
                }
            }
            else {
                observer.send(
                    value: GridViewCellModel(
                        assetID: nil,
                        image: nil,
                        durationText: "",
                        isFavourite: false
                    )
                )
                observer.sendCompleted()
            }
        }
    }
}
