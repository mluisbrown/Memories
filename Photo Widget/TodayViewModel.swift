//
//  TodayViewModel.swift
//  Memories
//
//  Created by Michael Brown on 16/01/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import Foundation
import Photos
import PHAssetHelper
import ReactiveSwift
import Result

struct TodayViewModel {
    private let cacheSize = CGSize(width: 256, height: 256)
    private let requestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        return options
    }()
    static private let noMemoriesText = NSLocalizedString("No Memories Today :(", comment: "")

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "YYYY"
        return df
    }()

    private let imageManager = PHCachingImageManager()
    private let assets = MutableProperty<[PHAsset]>([])
    private var count: Int {
        return assets.value.count
    }
    
    private let index = MutableProperty(-1)    
    private let currentAsset = MutableProperty<PHAsset?>(nil)
    
    private let _currentImage = MutableProperty<UIImage?>(nil)
    let currentImage: Property<UIImage?>
    
    private let _yearText = MutableProperty(noMemoriesText)
    let yearText: Property<String>
    
    init(date: Date) {
        currentImage = Property(_currentImage)
        yearText = Property(_yearText)
        createBindings()
        
        assets <~ loadAssets(for: date)
    }

    private func createBindings() {
        assets.signal
            .observeValues {
                if $0.count > 0 {
                    self.imageManager.startCachingImages(for: $0,
                                                         targetSize: self.cacheSize,
                                                         contentMode: .aspectFill,
                                                         options: self.requestOptions)
                    self.index.value = Int(arc4random_uniform(UInt32($0.count)))
                }
                else {
                    self.index.value = -1
                }
        }
        
        index.signal
            .observeValues {
                if $0 >= 0 && $0 < self.count {
                    self.currentAsset.value = self.assets.value[$0]
                }
                else {
                    self.currentAsset.value = nil
                }
        }

        currentAsset.signal
            .observeValues {
                if let asset = $0, let date = asset.creationDate {
                    self._yearText.value = self.dateFormatter.string(from: date)
                }
                else {
                    self._yearText.value = TodayViewModel.noMemoriesText
                }
        }
        
        currentAsset.signal
            .observeValues {
                if let asset = $0 {
                    self._currentImage <~ self.loadImageFor(asset: asset)
                }
                else {
                    self._currentImage.value = nil
                }
        }
    }
    
    private func loadAssets(for date: Date) -> SignalProducer<[PHAsset], NoError> {
        return SignalProducer<[PHAsset], NoError> { observer, _ in
            observer.send(value: PHAssetHelper().allAssetsForAllYears(with: date))
            observer.sendCompleted()
            }
            .start(on: QueueScheduler(qos: .userInitiated))
    }
    
    private func loadImageFor(asset: PHAsset) -> SignalProducer<UIImage, NoError> {
        return SignalProducer<UIImage, NoError> { observer, _ in
            self.imageManager.requestImage(for: asset,
                                           targetSize: self.cacheSize,
                                           contentMode: .aspectFill,
                                           options: self.requestOptions) { result, userInfo in
                
                if let image = result {
                    observer.send(value: image)

                    let isDegraded = ((userInfo?[PHImageResultIsDegradedKey] as? NSNumber) as? Bool) ?? false
                    if !isDegraded {
                        observer.sendCompleted()
                    }
                }
            }
        }
    }
    
    // MARK: - API
    func nextImage() {
        guard count > 0 else {
            return
        }
        
        index.value = (index.value + 1) % count
    }
    
    func previousImage() {
        guard count > 0 else {
            return
        }
        
        let newIndex = index.value - 1
        index.value = newIndex < 0 ? newIndex + count : newIndex
    }
}
