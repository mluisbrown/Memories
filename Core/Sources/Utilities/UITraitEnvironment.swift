import Foundation
import UIKit

extension UITraitEnvironment {
    public var thumbnailContentMode: UIView.ContentMode {
        let largeScreen = traitCollection.verticalSizeClass == .regular &&
                        traitCollection.horizontalSizeClass == .regular
        return largeScreen ? .scaleAspectFit : .scaleAspectFill
    }
}
