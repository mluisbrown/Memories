//
//  TodayViewModel.swift
//  Memories
//
//  Created by Michael Brown on 16/01/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import Foundation
import UIKit
import Photos
import PHAssetHelper
import ReactiveSwift

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
            .filter { $0.count > 0 }
            .observeValues {
                self.imageManager.startCachingImages(for: $0,
                                                     targetSize: self.cacheSize,
                                                     contentMode: .aspectFill,
                                                     options: self.requestOptions)
                self.index.value = Int(arc4random_uniform(UInt32($0.count)))
        }
        
        let currentAsset = index.signal
            .filter { $0 >= 0 && $0 < self.count }
            .map { self.assets.value[$0] }
        
        currentAsset.signal
            .compactMap { $0.creationDate }
            .observeValues {
                self._yearText.value = self.dateFormatter.string(from: $0)
        }
        
        currentAsset.signal
            .observeValues {
                self._currentImage <~ self.loadImageFor(asset: $0)
        }
    }
    
    private func loadAssets(for date: Date) -> SignalProducer<[PHAsset], Never> {
        return SignalProducer<[PHAsset], Never> { observer, _ in
            observer.send(value: PHAssetHelper().allAssetsForAllYears(with: date))
            observer.sendCompleted()
            }
            .start(on: QueueScheduler(qos: .userInitiated))
    }
    
    private func loadImageFor(asset: PHAsset) -> SignalProducer<UIImage, Never> {
        return SignalProducer<UIImage, Never> { observer, _ in
            self.imageManager.requestImage(for: asset,
                                           targetSize: self.cacheSize,
                                           contentMode: .aspectFill,
                                           options: self.requestOptions) { result, userInfo in
                
                if let image = result {
                    let isDegraded = ((userInfo?[PHImageResultIsDegradedKey] as? NSNumber) as? Bool) ?? true
                    
                    if !isDegraded {
                        observer.send(value: image)
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
