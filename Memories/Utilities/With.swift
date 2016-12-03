//
//  With.swift
//  Memories
//
//  Created by Michael Brown on 11/11/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import Foundation


public protocol With {}

extension With where Self: AnyObject {
    
    /// Makes it available to set properties with closures just after initializing.
    ///
    ///     let label = UILabel().with {
    ///       $0.textAlignment = .Center
    ///       $0.textColor = UIColor.blackColor()
    ///       $0.text = "Hello, World!"
    ///     }
    @discardableResult public func with(_ block: (Self) -> Void) -> Self {
        block(self)
        return self
    }
    
}

extension NSObject: With {}
