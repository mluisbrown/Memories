//
//  DateUtils.swift
//  Memories
//
//  Created by Michael Brown on 17/01/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import Foundation

public extension Date {
    
    @nonobjc static let gregorianCalendar = Calendar(identifier: Calendar.Identifier.gregorian)
    
    func addDays(_ days : Int) -> Date {
        return Date.gregorianCalendar.date(byAdding: .day, value: days, to: self)!
    }
    
    // MARK: API
    func nextDay() -> Date {
        return addDays(1)
    }
    
    func previousDay() -> Date {
        return addDays(-1)
    }
    
    var year: Int {
        let comps = Date.gregorianCalendar.dateComponents([.year], from: self)
        return comps.year!
    }
    
}
