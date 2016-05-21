//
//  PHAssetHelper.swift
//  Memories
//
//  Created by Michael Brown on 17/01/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import Foundation
import Photos

public class PHAssetHelper {
    
    private static var datesMapCache : [NSDate : Int]?
    private static var eariestAssetYearCache : Int?
    
    private let userDefaults : NSUserDefaults
    private let assetSourceTypesKey = "assetSourceTypes"

    public static let sourceTypesChangedNotification = "PHAssetHelperSourceTypesChangedNotification"
    
    public init() {
        userDefaults = NSUserDefaults.init(suiteName: "group.com.luacheia.memories")!
        if #available(iOS 9.0, *) {
            let types: PHAssetSourceType = [.TypeUserLibrary, .TypeiTunesSynced, .TypeCloudShared]
            userDefaults.registerDefaults([assetSourceTypesKey : NSNumber(unsignedLong: types.rawValue)])
        }
    }

    @available(iOS 9.0, *)
    public var assetSourceTypes: PHAssetSourceType {
        get {
            return PHAssetSourceType(rawValue: (userDefaults.valueForKey(assetSourceTypesKey) as! NSNumber).unsignedLongValue)
        }
        
        set {
            userDefaults.setValue(NSNumber(unsignedLong: newValue.rawValue), forKey: assetSourceTypesKey)
        }
    }
    
    private func earliestAssetYear() -> Int {
        guard PHAssetHelper.eariestAssetYearCache == nil else {
            return PHAssetHelper.eariestAssetYearCache!
        }
        
        // default to 2000
        var year = 2000
        
        let fetchResult = allAssetsInDateOrder()
        if let firstAsset = fetchResult.firstObject as? PHAsset {
            if let firstDate = firstAsset.creationDate {
                year = firstDate.year
            }
        }
        
        year = max(year, 1900)
        
        PHAssetHelper.eariestAssetYearCache = year;
        return year
    }
    
    public func refreshDatesMapCache() {
        PHAssetHelper.datesMapCache = nil
        
        let operation = NSBlockOperation {
            PHAssetHelper().datesMap()
        }
        
        let queue = NSOperationQueue()
        queue.addOperation(operation)
    }
    
    public func datesMap() -> [NSDate : Int] {
        guard PHAssetHelper.datesMapCache == nil else {
            return PHAssetHelper.datesMapCache!
        }
        
        var datesMap = [NSDate : Int]()
        guard PHPhotoLibrary.authorizationStatus() == .Authorized else {
            return datesMap
        }
        
        let fetchResult = allAssetsInDateOrder()
        let currentYear = NSDate().year
        let gregorian = NSDate.gregorianCalendar
        
        fetchResult.enumerateObjectsUsingBlock { object, index, stop in
            let asset : PHAsset = object as! PHAsset
            let comps = gregorian.components([.Month, .Day], fromDate: asset.creationDate!)
            let date = gregorian.dateWithEra(1, year: currentYear, month: comps.month, day: comps.day, hour: 12, minute: 0, second: 0, nanosecond: 0)!
            
            if let entry = datesMap[date] {
                datesMap[date] = entry + 1
            } else {
                datesMap[date] = 1
            }
        }
        
        PHAssetHelper.datesMapCache = datesMap
        return datesMap
    }
    
    public func allAssetsInDateOrder() -> PHFetchResult {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if #available(iOS 9.0, *) {
            options.includeAssetSourceTypes = assetSourceTypes
        }
        
        return PHAsset.fetchAssetsWithMediaType(.Image, options: options)
    }
    
    public func allAssetsForDateInAllYears(date: NSDate) -> [PHAsset] {
        let assetFetchResults = fetchResultsForDateInAllYears(date)
        var assets : [PHAsset] = [PHAsset]()
        
        for fetchResult in assetFetchResults {
            fetchResult.enumerateObjectsUsingBlock { object, index, stop in
                let asset : PHAsset = object as! PHAsset
                assets.append(asset)
            }
        }
        
        return assets
    }
    
    public func fetchResultsForDateInAllYears(date : NSDate) -> [PHFetchResult] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if #available(iOS 9.0, *) {
            options.includeAssetSourceTypes = assetSourceTypes
        }
        
        let startAndEndDates = startAndEndDatesForDateInYears(date, fromYear: earliestAssetYear(), toYear: NSDate().year)
        
        return startAndEndDates.map {
            NSPredicate(format: "creationDate >= %@ && creationDate <= %@", argumentArray: [$0.startDate, $0.endDate])
        }.map {
            options.predicate = $0
            return PHAsset.fetchAssetsWithMediaType(.Image, options: options)
        }.filter {
            $0.count > 0
        }
    }
    
    private func startAndEndDatesForDateInYears(date: NSDate, fromYear : Int, toYear : Int) -> [(startDate: NSDate, endDate: NSDate)] {
        let gregorian = NSDate.gregorianCalendar
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
    
}