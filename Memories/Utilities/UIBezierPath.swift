//
//  UIBezierPath.swift
//  Memories
//
//  Created by Michael Brown on 11/11/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import UIKit

extension UIBezierPath {

    convenience init(triangleOfSide side: CGFloat, offset: CGPoint = .zero) {
        self.init()
        
        let altitude = CGFloat(sqrt(3.0) / 2.0 * side)
        move(to: CGPoint(x: offset.x, y: offset.y))
        addLine(to: CGPoint(x: offset.x, y: side + offset.y))
        addLine(to: CGPoint(x: altitude + offset.x, y: (side / 2) + offset.y))
        close()
    }
    
}
