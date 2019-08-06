//
//  PhotoViewModel.swift
//  Memories
//
//  Created by Michael Brown on 11/02/2017.
//  Copyright © 2017 Michael Brown. All rights reserved.
//

import Foundation
import UIKit
import Photos
import AVFoundation
import ReactiveSwift

enum AssetResource {
    case photo(image: UIImage)
    case livePhoto(livePhoto: PHLivePhoto)
    case video(playerItem: AVPlayerItem)
}

final class PhotoViewModel {
    let asset: MutableProperty<PHAsset>
    let previewImage = MutableProperty<UIImage?>(nil)
    let assetResource = MutableProperty<AssetResource?>(nil)
    let assetRequestId = MutableProperty<PHImageRequestID?>(nil)
    
    let fullImageUnavailable = MutableProperty(false)
    let imageIsPreview = MutableProperty(true)
    let progress = MutableProperty(0.0)
    let indeterminateProgress = MutableProperty(false)

    init(asset: PHAsset) {
        self.asset = MutableProperty(asset)
    }
    
    func reset() {
        assetResource.value = nil
        previewImage.value = nil
        assetRequestId.value = nil
        
        fullImageUnavailable.value = false
        imageIsPreview.value = true
        progress.value = 0.0
        indeterminateProgress.value = false
    }
}
