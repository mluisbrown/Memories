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
    var selectedAsset : Int
    
    init (assets: [PHAsset], selectedAsset: Int) {
        self.assets = assets
        self.selectedAsset = selectedAsset
    }
    
}