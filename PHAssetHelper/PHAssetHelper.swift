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
    
    private static var datesMapCache : [Date : Int]?
    private static var eariestAssetYearCache : Int?
    
    private let userDefaults : UserDefaults
    private let assetSourceTypesKey = "assetSourceTypes"

    public static let sourceTypesChangedNotification = "PHAssetHelperSourceTypesChangedNotification"
    
    public init() {
        userDefaults = UserDefaults.init(suiteName: "group.com.luacheia.memories")!
        if #available(iOS 9.0, *) {
            let types: PHAssetSourceType = [.typeUserLibrary, .typeiTunesSynced, .typeCloudShared]
            userDefaults.register([assetSourceTypesKey : NSNumber(value: types.rawValue)])
        }
    }

    @available(iOS 9.0, *)
    public var assetSourceTypes: PHAssetSourceType {
        get {
            return PHAssetSourceType(rawValue: (userDefaults.value(forKey: assetSourceTypesKey) as! NSNumber).uintValue)
        }
        
        set {
            userDefaults.setValue(NSNumber(value: newValue.rawValue), forKey: assetSourceTypesKey)
        }
    }
    
    private func earliestAssetYear() -> Int {
        guard PHAssetHelper.eariestAssetYearCache == nil else {
            return PHAssetHelper.eariestAssetYearCache!
        }
        
        // default to 2000
        var year = 2000
        
        let fetchResult = allAssetsInDateOrder()
        if let firstAsset = fetchResult.firstObject as PHAsset? {
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
        
        let operation = BlockOperation {
            PHAssetHelper().datesMap()
        }
        
        let queue = OperationQueue()
        queue.addOperation(operation)
    }
    
    @discardableResult public func datesMap() -> [Date : Int] {
        guard PHAssetHelper.datesMapCache == nil else {
            return PHAssetHelper.datesMapCache!
        }
        
        var datesMap = [Date : Int]()
        guard PHPhotoLibrary.authorizationStatus() == .authorized else {
            return datesMap
        }
        
        let fetchResult = allAssetsInDateOrder()
        let currentYear = Date().year
        let gregorian = Date.gregorianCalendar
        
        fetchResult.enumerateObjects( { (asset, index, stop) -> Void in
            let comps = gregorian.components([.month, .day], from: asset.creationDate!)
            let date = gregorian.date(era: 1, year: currentYear, month: comps.month!, day: comps.day!, hour: 12, minute: 0, second: 0, nanosecond: 0)!
            
            if let entry = datesMap[date] {
                datesMap[date] = entry + 1
            } else {
                datesMap[date] = 1
            }
        })
        
        PHAssetHelper.datesMapCache = datesMap
        return datesMap
    }
    
    public func allAssetsInDateOrder() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [SortDescriptor(key: "creationDate", ascending: true)]
        if #available(iOS 9.0, *) {
            options.includeAssetSourceTypes = assetSourceTypes
        }
        
        return PHAsset.fetchAssets(with: .image, options: options)
    }
    
    public func allAssetsForDateInAllYears(_ date: Date) -> [PHAsset] {
        let assetFetchResults = fetchResultsForDateInAllYears(date)
        var assets : [PHAsset] = [PHAsset]()
        
        for fetchResult in assetFetchResults {
            fetchResult.enumerateObjects({ (asset, index, stop) -> Void in
                assets.append(asset)
            })
        }
        
        return assets
    }
    
    public func fetchResultsForDateInAllYears(_ date : Date) -> [PHFetchResult<PHAsset>] {
        let options = PHFetchOptions()
        options.sortDescriptors = [SortDescriptor(key: "creationDate", ascending: true)]
        if #available(iOS 9.0, *) {
            options.includeAssetSourceTypes = assetSourceTypes
        }
        
        let startAndEndDates = startAndEndDatesForDateInYears(date, fromYear: earliestAssetYear(), toYear: Date().year)
        
        return startAndEndDates.map {
            Predicate(format: "creationDate >= %@ && creationDate <= %@", argumentArray: [$0.startDate, $0.endDate])
        }.map {
            options.predicate = $0
            return PHAsset.fetchAssets(with: .image, options: options)
        }.filter {
            $0.count > 0
        }
    }
    
    private func startAndEndDatesForDateInYears(_ date: Date, fromYear : Int, toYear : Int) -> [(startDate: Date, endDate: Date)] {
        let gregorian = Date.gregorianCalendar
        var startComps = gregorian.components([.month, .day] , from: date)
        var endComps = gregorian.components([.month, .day] , from: date)
        
        startComps.hour = 0
        startComps.minute = 0
        startComps.second = 0
        endComps.hour = 23
        endComps.minute = 59
        endComps.second = 59
        
        return (fromYear...toYear).map {
            startComps.year = $0
            endComps.year = $0
            
            return (gregorian.date(from: startComps)!, gregorian.date(from: endComps)!)
        }
    }
    
}
