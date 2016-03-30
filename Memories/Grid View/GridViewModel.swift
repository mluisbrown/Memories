//
//  GridViewModel.swift
//  Memories
//
//  Created by Michael Brown on 16/07/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import Foundation
import Photos
import PHAssetHelper

class GridViewModel {
    let assetHelper = PHAssetHelper()
    var assetFetchResults = [PHFetchResult]()
    
    var date : Dynamic<NSDate>

    var sectionCount : Int {
        get {
            return assetFetchResults.count
        }
    }
    
    init() {
        self.date = Dynamic(NSDate())
        self.date.autoListener = {
            self.assetFetchResults = self.assetHelper.fetchResultsForDateInAllYears($0)
        }
    }
    
    init(date: NSDate) {
        self.date = Dynamic(date)
        self.date.autoListener = {
            self.assetFetchResults = self.assetHelper.fetchResultsForDateInAllYears($0)
        }
        self.assetFetchResults = self.assetHelper.fetchResultsForDateInAllYears(date)
    }

    // MARK: API
    func goToNextDay() {
        date.value = date.value.nextDay()
    }

    func goToPreviousDay() {
        date.value = date.value.previousDay()
    }
    
    func assetAtIndexPath(indexPath : NSIndexPath) -> PHAsset? {
        guard indexPath.section < assetFetchResults.count &&
            indexPath.item < assetFetchResults[indexPath.section].count else {
            return nil
        }
        
        return assetFetchResults[indexPath.section][indexPath.item] as? PHAsset
    }
    
    func numberOfSections() -> Int {
        return assetFetchResults.count
    }
    
    func numberOfItemsInSection(section : Int) -> Int {
        guard section < assetFetchResults.count else {
            return 0
        }
        
        return assetFetchResults[section].count
    }
    
    func yearForSection(section : Int) -> Int {
        guard section < assetFetchResults.count else {
            return 0
        }
        
        let asset = assetFetchResults[section].firstObject as! PHAsset
        let creationDate = asset.creationDate!
        
        return creationDate.year
    }
    
    func fetchResultForSection(section : Int) -> PHFetchResult? {
        guard section < assetFetchResults.count else {
            return nil
        }
        return assetFetchResults[section]
    }
    
    func setFetchResultForSection(section : Int, fetchResult : PHFetchResult) {
        guard section < assetFetchResults.count else {
            return
        }
        
        if fetchResult.count == 0 {
            assetFetchResults.removeAtIndex(section)
        } else {
            assetFetchResults[section] = fetchResult
        }
    }
    
    func photoViewModelForIndexPath(indexPath: NSIndexPath) -> PhotoViewModel {
        var assets : [PHAsset] = [PHAsset]()
        var selectedIndex = 0
        var currentIndex = 0
        
        for (section, fetchResult) in assetFetchResults.enumerate() {
            fetchResult.enumerateObjectsUsingBlock({ (object, index, stop) -> Void in
                let asset : PHAsset = object as! PHAsset
                assets.append(asset)
                if (section == indexPath.section && index == indexPath.item) {
                    selectedIndex = currentIndex
                }
                currentIndex += 1
            })
        }            
        
        return PhotoViewModel(assets: assets, selectedAsset: selectedIndex)
    }
    
    func indexPathForSelectedIndex(selectedIndex: Int) -> NSIndexPath {
        var sectionTotal = 0
        
        for (section, fetchResult) in assetFetchResults.enumerate() {
            if sectionTotal + fetchResult.count > selectedIndex {
                return NSIndexPath(forItem: selectedIndex - sectionTotal, inSection: section)
            }
            sectionTotal += fetchResult.count
        }
        
        return NSIndexPath()
    }
}
