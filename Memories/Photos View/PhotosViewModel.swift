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

    var currentIndex : Int
    let photoViewModels: [PhotoViewModel]
    let indexLoadedAndVisible = MutableProperty(0)

    init (assets: [PHAsset], currentIndex: Int) {
        self.photoViewModels = assets.map {
            return PhotoViewModel(asset: $0)
        }
        self.currentIndex = currentIndex
        
        imageManager.startCachingImages(for: assets, targetSize: cacheSize, contentMode: .aspectFill, options: nil)
    }

    var currentAsset: PHAsset {
        return photoViewModels[currentIndex].asset
    }
    
    var count: Int {
        return photoViewModels.count
    }
}

extension PhotosViewModel {
    func loadPreviewImageFor(index: Int) {
        let photoViewModel = photoViewModels[index]
        
        self.imageManager.requestImage(for: photoViewModel.asset, targetSize: self.cacheSize,
                                       contentMode: .aspectFill, options: nil, resultHandler: { result, userInfo in
            if let image = result {
                photoViewModel.previewImage.value = image
                
                if index == self.currentIndex {
                    self.indexLoadedAndVisible.value = index
                }
            }
        })
    }
    
    func loadHighQualityAssetFor(index: Int) {
        let photoViewModel = photoViewModels[index]
        let asset = photoViewModel.asset
        
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
                UpgradeManager.highQualityViewCount += 1
                photoViewModel.assetResource.value = assetResource
                if index == self.currentIndex {
                    self.indexLoadedAndVisible.value = index
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

            photoViewModel.assetRequestId.value = self.imageManager.requestImage(for: photoViewModel.asset,
                                                                                 targetSize: PHImageManagerMaximumSize,
                                                                                 contentMode: .aspectFit,
                                                                                 options: options) { result, userInfo in
                if let image = result {
                    observer.send(value: AssetResource.photo(image: image))
                }
                if let error = userInfo?[PHImageErrorKey] as? NSError {
                    observer.send(error: error)
                }
                observer.sendCompleted()
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

            photoViewModel.assetRequestId.value = self.imageManager.requestLivePhoto(for: photoViewModel.asset,
                                                                                     targetSize: PHImageManagerMaximumSize,
                                                                                     contentMode: .aspectFit,
                                                                                     options: options) { result, userInfo in
                if let livePhoto = result {
                    observer.send(value: AssetResource.livePhoto(livePhoto: livePhoto))
                }
                if let error = userInfo?[PHImageErrorKey] as? NSError {
                    observer.send(error: error)
                }
                observer.sendCompleted()
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
            
            photoViewModel.assetRequestId.value = self.imageManager.requestPlayerItem(forVideo: photoViewModel.asset,
                                                                                      options: options) { result, userInfo in
                if let video = result {
                    observer.send(value: AssetResource.video(playerItem: video))
                }
                if let error = userInfo?[PHImageErrorKey] as? NSError {
                    observer.send(error: error)
                }
                observer.sendCompleted()
            }
        }
    }
    
    func loadAssetDataForSharing(for index: Int) -> SignalProducer<Any, NoError> {
        return SignalProducer<Any, NoError> { observer, _ in
            let photoViewModel = self.photoViewModels[index]
            let asset = photoViewModel.asset
            
            switch asset.mediaType {
            case .image where asset.mediaSubtypes == .photoLive:
                if let assetResource = photoViewModel.assetResource.value,
                    case let .livePhoto(livePhoto) = assetResource {
                    observer.send(value: livePhoto)
                }
            case .image:
                let options = PHImageRequestOptions()
                options.version = .current
                options.isNetworkAccessAllowed = true
                self.imageManager.requestImageData(for: asset, options: options) { imageData, dataUTI, orientation, info in
                    if let imageData = imageData {
                        observer.send(value: imageData)
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
                    }
                }
            default:
                break
            }
            observer.sendCompleted()
        }
    }
    
    func resetPhotoViewModelFor(index: Int) {
        let photoViewModel = photoViewModels[index]
        
        if let requestId = photoViewModel.assetRequestId.value {
            imageManager.cancelImageRequest(requestId)
        }
        
        photoViewModel.reset()
    }
    
    func cancelAllAssetRequests() {
        photoViewModels.forEach {
            if let requestId = $0.assetRequestId.value {
                self.imageManager.cancelImageRequest(requestId)
                $0.assetRequestId.value = nil
            }
        }
    }
}
