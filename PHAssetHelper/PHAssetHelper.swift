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
    
    struct Key {
        static let assetSourceTypesKey = "assetSourceTypes"
        static let includeCurrentYearKey = "includeCurrentYear"
    }

    public static let sourceTypesChangedNotification = "PHAssetHelperSourceTypesChangedNotification"
    
    public init() {
        userDefaults = UserDefaults.init(suiteName: "group.com.luacheia.memories")!
        let types: PHAssetSourceType = [.typeUserLibrary, .typeiTunesSynced, .typeCloudShared]
        userDefaults.register(defaults: [Key.assetSourceTypesKey : NSNumber(value: types.rawValue),
                                         Key.includeCurrentYearKey: true])
    }

    public var assetSourceTypes: PHAssetSourceType {
        get {
            return PHAssetSourceType(rawValue: (userDefaults.value(forKey: Key.assetSourceTypesKey) as! NSNumber).uintValue)
        }
        
        set {
            userDefaults.setValue(NSNumber(value: newValue.rawValue), forKey: Key.assetSourceTypesKey)
        }
    }
    
    public var includeCurrentYear: Bool {
        get {
            return userDefaults.bool(forKey: Key.includeCurrentYearKey)
        }
         
        set {
            userDefaults.set(newValue, forKey: Key.includeCurrentYearKey)
        }
    }
    
    private func earliestAssetYear() -> Int {
        guard PHAssetHelper.eariestAssetYearCache == nil else {
            return PHAssetHelper.eariestAssetYearCache!
        }
        
        var year = 1990
        
        let fetchResult = allAssetsInDateOrder()
        if let firstAsset = fetchResult.firstObject as PHAsset? {
            if let firstDate = firstAsset.creationDate {
                year = firstDate.year
            }
        }
        
        year = max(min(1990, year), 1900)
        
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
            let comps = gregorian.dateComponents([.month, .day, .year], from: asset.creationDate!)
            guard self.includeCurrentYear || comps.year! < currentYear else {
                return
            }
            
            let date = gregorian.date(from: DateComponents(era: 1, year: currentYear, month: comps.month!, day: comps.day!, hour: 12, minute: 0, second: 0, nanosecond: 0))!
            
            if let entry = datesMap[date] {
                datesMap[date] = entry + 1
            } else {
                datesMap[date] = 1
            }
        })
        
        PHAssetHelper.datesMapCache = datesMap
        return datesMap
    }
    
    private func allAssetsInDateOrder() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.includeAssetSourceTypes = assetSourceTypes
        
        return PHAsset.fetchAssets(with: options)
    }
    
    public func allAssetsForAllYears(with date: Date) -> [PHAsset] {
        let assetFetchResults = fetchResultsForAllYears(with: date)
        var assets : [PHAsset] = [PHAsset]()
        
        for fetchResult in assetFetchResults {
            fetchResult.enumerateObjects({ (asset, index, stop) -> Void in
                assets.append(asset)
            })
        }
        
        return assets
    }
    
    public func fetchResultsForAllYears(with date : Date) -> [PHFetchResult<PHAsset>] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.includeAssetSourceTypes = assetSourceTypes
        
        let currentYear = Date().year - (includeCurrentYear ? 0 : 1)
        let startAndEndDates = self.startAndEndDates(for: date, fromYear: earliestAssetYear(), toYear: currentYear)
        
        return startAndEndDates.map {
            NSPredicate(format: "creationDate >= %@ && creationDate <= %@", argumentArray: [$0.startDate, $0.endDate])
        }.map {
            options.predicate = $0
            return PHAsset.fetchAssets(with: options)
        }.filter {
            $0.count > 0
        }
    }
    
    private func startAndEndDates(for date: Date, fromYear : Int, toYear : Int) -> [(startDate: Date, endDate: Date)] {
        let gregorian = Date.gregorianCalendar
        var startComps = gregorian.dateComponents([.month, .day] , from: date)
        var endComps = gregorian.dateComponents([.month, .day] , from: date)
        
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
