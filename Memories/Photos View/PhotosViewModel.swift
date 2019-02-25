//
//  PhotoViewModel.swift
//  Memories
//
//  Created by Michael Brown on 26/07/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import Foundation
import Photos
import ReactiveSwift
import Result

struct PhotosViewModel {
    let imageManager = PHCachingImageManager()
    // If the size is too large then PhotoKit doesn't return an optimal image size
    // see rdar://25181601 (https://openradar.appspot.com/radar?id=6158824289337344)
    let cacheSize = CGSize(width: 256, height: 256)

    let currentIndex = MutableProperty(0)
    private let _photoViewModels = MutableProperty([PhotoViewModel]())
    let photoViewModels: Property<[PhotoViewModel]>
    
    private let indexLoadedAndVisibleObserver: Signal<Int, NoError>.Observer
    let indexLoadedAndVisible: Signal<Int, NoError>
    
    private let currentAssetChangedObserver: Signal<PHAsset, NoError>.Observer
    let currentAssetChanged: Signal<PHAsset, NoError>
    
    private let libraryObserver: PhotoLibraryObserver

    init (assets: [PHAsset], currentIndex: Int, libraryObserver: PhotoLibraryObserver) {
        self._photoViewModels.value = assets.map {
            PhotoViewModel(asset: $0)
        }
        self.currentIndex.value = currentIndex
        self.libraryObserver = libraryObserver
        self.photoViewModels = Property(_photoViewModels)
        
        (indexLoadedAndVisible, indexLoadedAndVisibleObserver) = Signal<Int, NoError>.pipe()
        (currentAssetChanged, currentAssetChangedObserver) = Signal<PHAsset, NoError>.pipe()
        
        createBindings()
        
        imageManager.startCachingImages(for: assets, targetSize: cacheSize, contentMode: .aspectFill, options: nil)
    }

    private func createBindings() {
        libraryObserver.signal.observeValues {
            self.handleChange($0)
        }
    }
    
    var currentAsset: PHAsset {
        return photoViewModels.value[currentIndex.value].asset.value
    }
    
    var count: Int {
        return photoViewModels.value.count
    }
    
    func photoViewModel(at index: Int) -> PhotoViewModel {
        return photoViewModels.value[index]
    }
    
    func asset(at index: Int) -> PHAsset {
        return photoViewModel(at: index).asset.value
    }
    
    func indexBecameVisible(_ index: Int) {
        self.indexLoadedAndVisibleObserver.send(value: index)
    }
}

extension PhotosViewModel {
    func loadPreviewImageFor(index: Int) {
        let photoViewModel = photoViewModels.value[index]
        
        self.imageManager.requestImage(for: photoViewModel.asset.value, 
                                                                               targetSize: self.cacheSize,
                                                                               contentMode: .aspectFill, 
                                                                               options: nil, 
                                                                               resultHandler: { result, userInfo in
            if let image = result {
                photoViewModel.previewImage.value = image
                
                if index == self.currentIndex.value {
                    self.indexBecameVisible(index)
                }
            }
        })
    }
    
    func loadHighQualityAssetFor(index: Int) {
        let photoViewModel = photoViewModels.value[index]
        let asset = photoViewModel.asset.value
        
        let progressHandler: PHAssetImageProgressHandler = { progress, error, stop, userInfo in
            photoViewModel.progress.value = progress
            
            if error != nil {
                photoViewModel.fullImageUnavailable.value = true
            }
        }

        let assetProducer: SignalProducer<AssetResource, NSError>?
        
        switch asset.mediaType {
        case .image where asset.mediaSubtypes == .photoLive:
            assetProducer = loadLivePhoto(for: photoViewModel, progressHandler: progressHandler)
        case .image:
            assetProducer = loadPhoto(for: photoViewModel, progressHandler: progressHandler)
        case .video:
            assetProducer = loadVideo(for: photoViewModel, progressHandler: progressHandler)
        default:
            assetProducer = nil
        }
        
        assetProducer?.startWithResult { result in
            switch result {
            case .success(let assetResource):                
                photoViewModel.assetResource.value = assetResource
                if index == self.currentIndex.value {
                    self.indexBecameVisible(index)
                }
            case .failure:
                photoViewModel.fullImageUnavailable.value = true
            }
        }
    }

    private func loadPhoto(for photoViewModel: PhotoViewModel,
                           progressHandler: @escaping PHAssetImageProgressHandler) -> SignalProducer<AssetResource, NSError> {
        return SignalProducer<AssetResource, NSError> { observer, _ in
            let options = PHImageRequestOptions()
            
            options.progressHandler = progressHandler
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false

            photoViewModel.assetRequestId.value = self.imageManager.requestImage(for: photoViewModel.asset.value,
                                                                                 targetSize: PHImageManagerMaximumSize,
                                                                                 contentMode: .aspectFit,
                                                                                 options: options) { result, userInfo in
                let isDegraded = (userInfo?[PHImageResultIsDegradedKey] as? NSNumber) ?? false
                                                                                    
                if let image = result, !(isDegraded as! Bool) {
                    observer.send(value: AssetResource.photo(image: image))
                    observer.sendCompleted()
                }
                else if let error = userInfo?[PHImageErrorKey] as? NSError {
                    observer.send(error: error)
                    observer.sendCompleted()
                }
            }
        }
    }
    
    private func loadLivePhoto(for photoViewModel: PhotoViewModel,
                               progressHandler: @escaping PHAssetImageProgressHandler) -> SignalProducer<AssetResource, NSError> {
        return SignalProducer<AssetResource, NSError> { observer, _ in
            photoViewModel.indeterminateProgress.value = true
            
            let options = PHLivePhotoRequestOptions()
            
            options.progressHandler = progressHandler
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            photoViewModel.assetRequestId.value = self.imageManager.requestLivePhoto(for: photoViewModel.asset.value,
                                                                                     targetSize: PHImageManagerMaximumSize,
                                                                                     contentMode: .aspectFit,
                                                                                     options: options) { result, userInfo in
                let isDegraded = (userInfo?[PHImageResultIsDegradedKey] as? NSNumber) ?? false
                if let livePhoto = result, !(isDegraded as! Bool) {
                    observer.send(value: AssetResource.livePhoto(livePhoto: livePhoto))
                    observer.sendCompleted()
                }
                else if let error = userInfo?[PHImageErrorKey] as? NSError {
                    observer.send(error: error)
                    observer.sendCompleted()
                }
            }
        }
    }
    
    private func loadVideo(for photoViewModel: PhotoViewModel,
                           progressHandler: @escaping PHAssetImageProgressHandler) -> SignalProducer<AssetResource, NSError> {
        return SignalProducer<AssetResource, NSError> { observer, _ in
            photoViewModel.indeterminateProgress.value = true

            let options = PHVideoRequestOptions()
            
            options.progressHandler = progressHandler
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic
            
            photoViewModel.assetRequestId.value = self.imageManager.requestPlayerItem(forVideo: photoViewModel.asset.value,
                                                                                      options: options) { result, userInfo in
                if let video = result {
                    observer.send(value: AssetResource.video(playerItem: video))
                    observer.sendCompleted()
                }
                else if let error = userInfo?[PHImageErrorKey] as? NSError {
                    observer.send(error: error)
                    observer.sendCompleted()
                }
            }
        }
    }
    
    func loadAssetDataForSharing(for index: Int) -> SignalProducer<Any, NoError> {
        return SignalProducer<Any, NoError> { observer, _ in
            let photoViewModel = self.photoViewModels.value[index]
            let asset = photoViewModel.asset.value
            
            switch asset.mediaType {
            case .image where asset.mediaSubtypes == .photoLive:
                if let assetResource = photoViewModel.assetResource.value,
                    case let .livePhoto(livePhoto) = assetResource {
                    observer.send(value: livePhoto)
                    observer.sendCompleted()
                }
            case .image:
                let options = PHImageRequestOptions()
                options.version = .current
                options.isNetworkAccessAllowed = true
                self.imageManager.requestImageData(for: asset, options: options) { imageData, dataUTI, orientation, info in
                    if let imageData = imageData {
                        observer.send(value: imageData)
                        observer.sendCompleted()
                    }
                }
            case .video:
                let options = PHVideoRequestOptions()
                options.version = .current
                options.deliveryMode = .automatic
                options.isNetworkAccessAllowed = true
                
                self.imageManager.requestAVAsset(forVideo: asset, options: options) { asset, audioMix, info in
                    if let urlAsset = asset as? AVURLAsset {
                        observer.send(value: urlAsset.url)
                        observer.sendCompleted()
                    }
                }
            default:
                break
            }
        }
    }
    
    func resetPhotoViewModelFor(index: Int) {
        guard index > 0 && index < photoViewModels.value.count else {
            return
        }
        
        let photoViewModel = photoViewModels.value[index]
        
        if let requestId = photoViewModel.assetRequestId.value {
            imageManager.cancelImageRequest(requestId)
        }
        
        photoViewModel.reset()
    }
    
    func cancelAllAssetRequests() {
        photoViewModels.value.forEach {
            if let requestId = $0.assetRequestId.value {
                self.imageManager.cancelImageRequest(requestId)
                $0.assetRequestId.value = nil
            }
        }
    }
}

extension PhotosViewModel {
    func deleteCurrentAsset() {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(NSArray(array: [self.currentAsset]))
        })
    }
    
    func toggleFavoriteCurrentAsset() {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: self.currentAsset)
            request.isFavorite = !self.currentAsset.isFavorite
        })
    }
}

extension PhotosViewModel {
    func handleChange(_ changeInstance: PHChange) {
        let newAssets:[PHAsset] = photoViewModels.value.compactMap {
            if let changeDetails = changeInstance.changeDetails(for: $0.asset.value) {
                return changeDetails.objectWasDeleted ? nil : changeDetails.objectAfterChanges
            }
            else {
                return $0.asset.value
            }
        }
        
        if newAssets.count != count {
            currentIndex.value = min(currentIndex.value, newAssets.count - 1)
            self._photoViewModels.value = newAssets.map {
                PhotoViewModel(asset: $0)
            }
        }
        else {
            newAssets.enumerated().forEach {
                self.photoViewModels.value[$0.offset].asset.value = $0.element
            }
            currentAssetChangedObserver.send(value: currentAsset)
        }
    }
}
