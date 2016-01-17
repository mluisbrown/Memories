//
//  TodayViewModel.swift
//  Memories
//
//  Created by Michael Brown on 16/01/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import Foundation
import Photos

class TodayViewModel {
    let date : NSDate
    let assets : [PHAsset]
    var index = 0
    
    static let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
    
    init(date: NSDate) {
        self.date = date
        assets = TodayViewModel.allAssetsForDate(self.date)
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
    
    static private func allAssetsForDate(date: NSDate) -> [PHAsset] {
        let assetFetchResults = buildFetchResultsForDate(date)
        var assets : [PHAsset] = [PHAsset]()
        
        for fetchResult in assetFetchResults {
            fetchResult.enumerateObjectsUsingBlock({ (object, index, stop) -> Void in
                let asset : PHAsset = object as! PHAsset
                assets.append(asset)
            })
        }
        
        return assets
    }
    

    static private func calculateEarliestAssetYear() -> Int {
        // default to 2000
        var year = 2000
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if #available(iOS 9.0, *) {
            options.includeAssetSourceTypes = [.TypeUserLibrary, .TypeiTunesSynced, .TypeCloudShared]
        }
        
        let fetchResult = PHAsset.fetchAssetsWithMediaType(.Image, options: options)
        if let firstAsset = fetchResult.firstObject as? PHAsset {
            if let firstDate = firstAsset.creationDate {
                let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                year = gregorian.component(.Year, fromDate: firstDate)
            }
        }
        
        return year
    }
    
    static private func buildFetchResultsForDate(date : NSDate) -> [PHFetchResult] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if #available(iOS 9.0, *) {
            options.includeAssetSourceTypes = [.TypeUserLibrary, .TypeiTunesSynced, .TypeCloudShared]
        }
        
        let startAndEndDates = TodayViewModel.startAndEndDatesForDate(date, fromYear: TodayViewModel.calculateEarliestAssetYear(), toYear: TodayViewModel.gregorian.component(.Year, fromDate: NSDate()))
        
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

}