//
//  DateUtils.swift
//  Memories
//
//  Created by Michael Brown on 17/01/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import Foundation

public extension NSDate {
    
    @nonobjc static let gregorianCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
    
    func addDays(days : Int) -> NSDate {
        return NSDate.gregorianCalendar.dateByAddingUnit(.Day, value: days, toDate: self, options: NSCalendarOptions(rawValue: 0))!
    }
    
    // MARK: API
    func nextDay() -> NSDate {
        return addDays(1)
    }
    
    func previousDay() -> NSDate {
        return addDays(-1)
    }
    
    func year() -> Int {
        let comps = NSDate.gregorianCalendar.components(.Year, fromDate: self)
        return comps.year
    }
    
}