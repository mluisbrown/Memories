//
//  UITraitEnvironment.swift
//  Memories
//
//  Created by Michael Brown on 29/03/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import Foundation
import UIKit

public extension UITraitEnvironment {
    var thumbnailContentMode: UIView.ContentMode {
        let largeScreen = traitCollection.verticalSizeClass == .regular &&
                        traitCollection.horizontalSizeClass == .regular
        return largeScreen ? .scaleAspectFit : .scaleAspectFill
    }
}
