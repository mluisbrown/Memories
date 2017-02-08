//
//  PhotoViewModel.swift
//  Memories
//
//  Created by Michael Brown on 26/07/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import Foundation
import Photos

struct PhotoViewModel {
    let assets : [PHAsset]
    var currentIndex : Int
    
    init (assets: [PHAsset], currentIndex: Int) {
        self.assets = assets
        self.currentIndex = currentIndex
    }

    var currentAsset: PHAsset {
        return assets[currentIndex]
    }
    
}
