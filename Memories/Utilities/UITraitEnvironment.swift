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
    var thumbnailContentMode: UIViewContentMode {
        let largeScreen = traitCollection.verticalSizeClass == .Regular &&
                        traitCollection.horizontalSizeClass == .Regular
        return largeScreen ? .ScaleAspectFit : .ScaleAspectFill
    }
}
