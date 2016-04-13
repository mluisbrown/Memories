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
    var assets = [PHAsset]()
    var index = -1
    
    init(date: NSDate, onDataReady: () -> ()) {
        self.date = date
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) { [unowned self] in
            self.assets = self.assetHelper.allAssetsForDateInAllYears(date)
            dispatch_async(dispatch_get_main_queue()) {
                onDataReady()
            }
        }
    }
    
    
    private func randomAsset() -> PHAsset? {
        guard assets.count > 0 else {
            return nil
        }
        
        index = Int(arc4random_uniform(UInt32(assets.count)))
        return assets[index]
    }
    
    func currentAsset() -> PHAsset? {
        guard assets.count > 0 else {
            return nil
        }

        if index < 1 {
            return randomAsset()
        }
        
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