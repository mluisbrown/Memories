//
//  CAShapeLayer.swift
//  Memories
//
//  Created by Michael Brown on 11/11/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import UIKit
import QuartzCore

extension CAShapeLayer {
    
    static func circlePlayShape(fillColor: UIColor, diameter: CGFloat) -> CAShapeLayer {
        let frame = CGRect(origin: CGPoint.zero, size: CGSize(width: diameter, height: diameter))
        let circle = CAShapeLayer()
        circle.frame = frame
        
        let circlePath = UIBezierPath(ovalIn: frame)
        let trainglePath = UIBezierPath(triangleOfSide: diameter / 2, offset: CGPoint(x: diameter / 3, y: diameter / 4))
        circlePath.append(trainglePath)

        circle.path = circlePath.cgPath
        circle.fillColor = fillColor.cgColor
        
        return circle
    }
}
