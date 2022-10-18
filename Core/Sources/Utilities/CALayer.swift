import UIKit

extension CALayer {
    public func toImage() -> UIImage? {
        UIGraphicsImageRenderer(size: self.frame.size).image { ctx in
            render(in: ctx.cgContext)
        }
    }
}
