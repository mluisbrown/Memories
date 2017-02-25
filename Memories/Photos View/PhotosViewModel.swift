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
        
        self.imageManager.requestImage(for: photoViewModel.asset, targetSize: self.cacheSize, contentMode: .aspectFill, options: nil, resultHandler: { result, userInfo in
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
        
        let configurePageView = { (asset: PHAsset) in
            return { (data: AssetResource?) in
                guard let data = data else {
                    photoViewModel.fullImageUnavailable.value = true
                    return
                }
                UpgradeManager.highQualityViewCount += 1
                
                photoViewModel.assetResource.value = data
                
                if index == self.currentIndex {
                    self.indexLoadedAndVisible.value = index
                }
            }
        }
        
        switch asset.mediaType {
        case .image where asset.mediaSubtypes == .photoLive:
            photoViewModel.indeterminateProgress.value = true
            photoViewModel.assetRequestId.value = loadLivePhoto(for: asset, progressHandler: progressHandler, completion: configurePageView(asset))
        case .image:
            photoViewModel.assetRequestId.value = loadPhoto(for: asset, progressHandler: progressHandler, completion: configurePageView(asset))
        case .video:
            photoViewModel.indeterminateProgress.value = true
            photoViewModel.assetRequestId.value = loadVideo(for: asset, progressHandler: progressHandler, completion: configurePageView(asset))
            break
        default:
            break
        }
    }
    
    private func loadPhoto(for asset: PHAsset, progressHandler: @escaping PHAssetImageProgressHandler, completion: @escaping (AssetResource?) -> Void) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        
        options.progressHandler = progressHandler
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        
        return PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { (result, userInfo) -> Void in
            if let image = result {
                completion(AssetResource.photo(image: image))
            }
            
            if let _ = userInfo?[PHImageErrorKey] as? NSError {
                completion(nil)
            }
        }
    }
    
    private func loadLivePhoto(for asset: PHAsset, progressHandler: @escaping PHAssetImageProgressHandler, completion: @escaping (AssetResource?) -> Void) -> PHImageRequestID {
        let options = PHLivePhotoRequestOptions()
        
        options.progressHandler = progressHandler
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        return PHImageManager.default().requestLivePhoto(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { (result, userInfo) -> Void in
            if let livePhoto = result {
                completion(AssetResource.livePhoto(livePhoto: livePhoto))
            }
            
            if let _ = userInfo?[PHImageErrorKey] as? NSError {
                completion(nil)
            }
        }
    }
    
    private func loadVideo(for asset: PHAsset, progressHandler: @escaping PHAssetImageProgressHandler, completion: @escaping (AssetResource?) -> Void) -> PHImageRequestID {
        let options = PHVideoRequestOptions()
        
        options.progressHandler = progressHandler
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        
        return PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { (result, userInfo) -> Void in
            if let video = result {
                completion(AssetResource.video(playerItem: video))
            }
            
            if let _ = userInfo?[PHImageErrorKey] as? NSError {
                completion(nil)
            }
        }
    }
    
    func resetPhotoViewModelFor(index: Int) {
        let photoViewModel = photoViewModels[index]
        
        if let requestId = photoViewModel.assetRequestId.value {
            PHImageManager.default().cancelImageRequest(requestId)
        }
        
        photoViewModel.reset()
    }
    
    func cancelAllAssetRequests() {
        photoViewModels.forEach {
            if let requestId = $0.assetRequestId.value {
                PHImageManager.default().cancelImageRequest(requestId)
                $0.assetRequestId.value = nil
            }
        }
    }
}
