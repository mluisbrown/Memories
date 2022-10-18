import Foundation

extension DateComponentsFormatter {
    public func videoDuration(from duration: TimeInterval) -> String? {
        zeroFormattingBehavior = .pad
        allowedUnits = duration > 3600 ? [.hour, .minute, .second] : [.minute, .second]
        
        return string(from: round(duration))
    }
}
