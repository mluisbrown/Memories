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
    private let assetHelper = PHAssetHelper()
    private var assetFetchResults = [PHFetchResult<PHAsset>]()
    
    let date : Dynamic<Date>
    let onDataChanged: (Date) -> ()
    
    var sectionCount : Int {
        get {
            return assetFetchResults.count
        }
    }
    
    init(onDataChanged: @escaping (Date) -> ()) {
        self.onDataChanged = onDataChanged
        self.date = Dynamic(Date())
        self.date.bind {
            self.fetchDataAndNotify($0)
        }
    }
    
    init(date: Date, onDataChanged: @escaping (Date) -> ()) {
        self.onDataChanged = onDataChanged
        self.date = Dynamic(date)
        self.date.bindAndFire {
            self.fetchDataAndNotify($0)
        }
    }

    private func fetchDataAndNotify(_ date: Date) {
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            self.assetFetchResults = self.assetHelper.fetchResultsForDateInAllYears(date)
            DispatchQueue.main.async { [unowned self] in
                self.onDataChanged(self.date.value)
            }
        }
    }
    
    // MARK: - API
    func goToNextDay() {
        date.value = date.value.nextDay()
    }

    func goToPreviousDay() {
        date.value = date.value.previousDay()
    }
    
    func assetAtIndexPath(_ indexPath : IndexPath) -> PHAsset? {
        guard (indexPath as NSIndexPath).section < assetFetchResults.count &&
            (indexPath as NSIndexPath).item < assetFetchResults[(indexPath as NSIndexPath).section].count else {
            return nil
        }
        
        return assetFetchResults[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).item] as PHAsset?
    }
    
    func numberOfSections() -> Int {
        return assetFetchResults.count
    }
    
    func numberOfItemsInSection(_ section : Int) -> Int {
        guard section < assetFetchResults.count else {
            return 0
        }
        
        return assetFetchResults[section].count
    }
    
    func yearForSection(_ section : Int) -> Int {
        guard section < assetFetchResults.count else {
            return 0
        }
        
        let asset = assetFetchResults[section].firstObject!
        let creationDate = asset.creationDate!
        
        return creationDate.year
    }
    
    func fetchResultForSection(_ section : Int) -> PHFetchResult<PHAsset>? {
        guard section < assetFetchResults.count else {
            return nil
        }
        return assetFetchResults[section]
    }
    
    func setFetchResultForSection(_ section : Int, fetchResult : PHFetchResult<PHAsset>) {
        guard section < assetFetchResults.count else {
            return
        }
        
        if fetchResult.count == 0 {
            assetFetchResults.remove(at: section)
        } else {
            assetFetchResults[section] = fetchResult
        }
    }
    
    func photoViewModelForIndexPath(_ indexPath: IndexPath) -> PhotoViewModel {
        var assets : [PHAsset] = [PHAsset]()
        var selectedIndex = 0
        var currentIndex = 0
        
        for (section, fetchResult) in assetFetchResults.enumerated() {
            fetchResult.enumerateObjects({ (asset, index, stop) -> Void in
                assets.append(asset)
                if (section == (indexPath as NSIndexPath).section && index == (indexPath as NSIndexPath).item) {
                    selectedIndex = currentIndex
                }
                currentIndex += 1
            })
        }            
        
        return PhotoViewModel(assets: assets, selectedAsset: selectedIndex)
    }
    
    func indexPathForSelectedIndex(_ selectedIndex: Int) -> IndexPath {
        var sectionTotal = 0
        
        for (section, fetchResult) in assetFetchResults.enumerated() {
            if sectionTotal + fetchResult.count > selectedIndex {
                return IndexPath(item: selectedIndex - sectionTotal, section: section)
            }
            sectionTotal += fetchResult.count
        }
        
        return IndexPath()
    }
}
