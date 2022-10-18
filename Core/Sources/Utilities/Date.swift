import Foundation

extension Date {
    
    @nonobjc public static let gregorianCalendar = Calendar(identifier: Calendar.Identifier.gregorian)
    
    public func addDays(_ days : Int) -> Date {
        return Date.gregorianCalendar.date(byAdding: .day, value: days, to: self)!
    }
    
    public func nextDay() -> Date {
        return addDays(1)
    }
    
    public func previousDay() -> Date {
        return addDays(-1)
    }
    
    public var year: Int {
        let comps = Date.gregorianCalendar.dateComponents([.year], from: self)
        return comps.year!
    }
}
