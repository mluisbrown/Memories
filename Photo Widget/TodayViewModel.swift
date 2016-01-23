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

class TodayViewModel {
    let assetHelper = PHAssetHelper()
    
    let date : NSDate
    let assets : [PHAsset]
    var index = 0
    
    init(date: NSDate) {
        self.date = date
        assets = assetHelper.allAssetsForDateInAllYears(date)
    }
    
    func randomAsset() -> PHAsset? {
        guard assets.count > 0 else {
            return nil
        }
        
        index = Int(arc4random_uniform(UInt32(assets.count)))
        return assets[index]
    }
    
    func nextAsset() -> PHAsset? {
        guard assets.count > 0 else {
            return nil
        }
        
        index = (index + 1) % assets.count
        return assets[index]
    }
    
    func previousAsset() -> PHAsset? {
        guard assets.count > 0 else {
            return nil
        }
        
        index = index - 1
        index = index < 0 ? index + assets.count : index

        return assets[index]
    }
}