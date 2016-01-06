//
//  GridViewModel.swift
//  Memories
//
//  Created by Michael Brown on 16/07/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import Foundation
import Photos

class GridViewModel {
    static var earliestYear : Int?
    
    static let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
    var assetFetchResults = [PHFetchResult]() 
    var earliestAssetYear : Int {
        get {
            if let year = GridViewModel.earliestYear {
                return year
            }
            
            return GridViewModel.calculateEarliestAssetYear()
        }
    }
    
    var date : Dynamic<NSDate>

    var sectionCount : Int {
        get {
            return assetFetchResults.count
        }
    }
    
    init() {
        self.date = Dynamic(NSDate())
        self.date.autoListener = {
            self.assetFetchResults = self.buildFetchResultsForDate($0)
        }
    }
    
    init(date: NSDate) {
        self.date = Dynamic(date)
        self.date.autoListener = {
            self.assetFetchResults = self.buildFetchResultsForDate($0)
        }
        self.assetFetchResults = self.buildFetchResultsForDate(date)
    }

    static private func calculateEarliestAssetYear() -> Int {
        // default to 2000
        var year = 2000
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let fetchResult = PHAsset.fetchAssetsWithMediaType(.Image, options: options)
        if let firstAsset = fetchResult.firstObject as? PHAsset {
            if let firstDate = firstAsset.creationDate {
                let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                year = gregorian.component(.Year, fromDate: firstDate)
            }
        }
        
        earliestYear = year
        return year
    }

    private func buildFetchResultsForDate(date : NSDate) -> [PHFetchResult] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if #available(iOS 9.0, *) {
            options.includeAssetSourceTypes = [.TypeUserLibrary, .TypeiTunesSynced, .TypeCloudShared]
        }
        
        let startAndEndDates = GridViewModel.startAndEndDatesForDate(date, fromYear: earliestAssetYear, toYear: GridViewModel.gregorian.component(.Year, fromDate: NSDate()))
        
        return startAndEndDates.map {
            NSPredicate(format: "creationDate >= %@ && creationDate <= %@", argumentArray: [$0.startDate, $0.endDate])
        }.map {
            options.predicate = $0
            return PHAsset.fetchAssetsWithMediaType(.Image, options: options)
        }.filter {
            $0.count > 0
        }
    }
    
    static private func startAndEndDatesForDate(date: NSDate, fromYear : Int, toYear : Int) -> [(startDate: NSDate, endDate: NSDate)] {
        let startComps = gregorian.components([.Month, .Day] , fromDate: date)
        let endComps = gregorian.components([.Month, .Day] , fromDate: date)

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
    
    static func addDaysToDate(date: NSDate, days : Int) -> NSDate {
        return gregorian.dateByAddingUnit(.Day, value: days, toDate: date, options: NSCalendarOptions(rawValue: 0))!
    }
    
    // MARK: API
    static func nextDay(date: NSDate) -> NSDate {
        return addDaysToDate(date, days: 1)
    }

    static func previousDay(date: NSDate) -> NSDate {
        return addDaysToDate(date, days: -1)
    }    
    
    func goToNextDay() {
        date.value = GridViewModel.nextDay(date.value)
    }

    func goToPreviousDay() {
        date.value = GridViewModel.previousDay(date.value)
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
        let creationDate = asset.creationDate
        let comps = GridViewModel.gregorian.components(.Year, fromDate: creationDate!)
        
        return comps.year
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
                currentIndex++
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
