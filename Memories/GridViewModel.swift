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

    var date : NSDate? {
        didSet {
            buildFetchResultsForDate(date)
        }
    }
    
    var sectionCount : Int {
        get {
            return assetFetchResults.count
        }
    }
    
    init() {
    }
    
    init(date: NSDate?) {
        self.date = date
        self.buildFetchResultsForDate(date)
    }

    private func earliestAssetYear() -> Int {
        // default to 2000
        var year = 2000
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let fetchResult = PHAsset.fetchAssetsWithMediaType(.Image, options: options)
        if let firstAsset = fetchResult.firstObject as? PHAsset {
            if let firstDate = firstAsset.creationDate {
                year = gregorian.component(.Year, fromDate: firstDate)
            }
        }
        
        return year
    }
    
    private mutating func buildFetchResultsForDate(date : NSDate?) {
        // clean out previous fetch results
        assetFetchResults = [PHFetchResult]()
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let startAndEndDates = startAndEndDatesForDate(date, fromYear: earliestAssetYear(), toYear: gregorian.component(.Year, fromDate: NSDate()))
        
        assetFetchResults = startAndEndDates.map {
            NSPredicate(format: "creationDate >= %@ && creationDate <= %@", argumentArray: [$0.startDate, $0.endDate])
        }.map {
            options.predicate = $0
            return PHAsset.fetchAssetsWithMediaType(.Image, options: options)
        }.filter {
            $0.count > 0
        }
    }
    
    private func startAndEndDatesForDate(date: NSDate?, fromYear : Int, toYear : Int) -> [(startDate: NSDate, endDate: NSDate)] {
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

        return (fromYear...toYear).map {
            startComps.year = $0
            endComps.year = $0
            
            return (gregorian.dateFromComponents(startComps)!, gregorian.dateFromComponents(endComps)!)
        }
    }
    
    func addDaysToDate(date: NSDate?, days : Int) -> NSDate? {
        guard date != nil else {
            return nil
        }
        
        return gregorian.dateByAddingUnit(.Day, value: days, toDate: date!, options: NSCalendarOptions(rawValue: 0))
    }
    
    // MARK: API
    func nextDay() -> NSDate? {
        return addDaysToDate(date, days: 1)
    }

    func previousDay() -> NSDate? {
        return addDaysToDate(date, days: -1)
    }    
    
    mutating func goToNextDay() {
        date = nextDay()
    }

    mutating func goToPreviousDay() {
        date = previousDay()
    }
    
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
