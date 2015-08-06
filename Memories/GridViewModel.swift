//
//  GridViewModel.swift
//  Memories
//
//  Created by Michael Brown on 16/07/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import Foundation
import Photos

struct GridViewModel {
    let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
    var assetFetchResults = [PHFetchResult]()
    
    var sectionCount : Int {
        get {
            return assetFetchResults.count
        }
    }
    
    init() {
        self.init(date: nil)
    }
    
    init(date: NSDate?) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let startAndEndDates = startAndEndDatesForDate(date, fromYear: 2000, toYear: 2015)
        
        var predicates = [NSPredicate]()
        
        for startAndEndDate in startAndEndDates {
            let (startDate, endDate) = startAndEndDate
            let predicate = NSPredicate(format: "creationDate >= %@ && creationDate <= %@", argumentArray: [startDate, endDate])
            predicates.append(predicate)
        }
        
        for predicate in predicates {
            options.predicate = predicate
            let fetchResult = PHAsset.fetchAssetsWithOptions(options)
            
            if fetchResult.count > 0 {
                self.assetFetchResults.append(fetchResult)
            }
        }
    }

    private func startAndEndDatesForDate(date : NSDate?, fromYear : Int, toYear : Int) -> [(NSDate, NSDate)] {
        let startComps : NSDateComponents
        let endComps : NSDateComponents
        if date != nil {
            startComps = gregorian.components([.Month, .Day] , fromDate: date!)
            endComps = gregorian.components([.Month, .Day] , fromDate: date!)
        } else {
            startComps = NSDateComponents()
            startComps.day = 1
            startComps.month = 1
            endComps = NSDateComponents()
            endComps.day = 31
            endComps.month = 12
        }
        
        startComps.hour = 0
        startComps.minute = 0
        startComps.second = 0
        endComps.hour = 23
        endComps.minute = 59
        endComps.second = 59
        
        var startAndEndDates = [(NSDate, NSDate)]()
        
        for year in fromYear...toYear {
            startComps.year = year
            endComps.year = year
            
            let startDate = gregorian.dateFromComponents(startComps)
            let endDate = gregorian.dateFromComponents(endComps)
            
            startAndEndDates.append((startDate!, endDate!))
        }
        
        return startAndEndDates
    }
    
    // MARK: API
    
    func assetAtIndexPath(indexPath : NSIndexPath) -> PHAsset? {
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
        let creationDate = asset.creationDate
        let comps = gregorian.components(.Year, fromDate: creationDate!)
        
        return comps.year
    }
    
    func fetchResultForSection(section : Int) -> PHFetchResult? {
        guard section < assetFetchResults.count else {
            return nil
        }
        return assetFetchResults[section]
    }
    
    mutating func setFetchResultForSection(section : Int, fetchResult : PHFetchResult) {
        guard section < assetFetchResults.count else {
            return
        }
        
        self.assetFetchResults[section] = fetchResult
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
                currentIndex++
            })
        }            
        
        return PhotoViewModel(assets: assets, selectedAsset: selectedIndex)
    }
}
