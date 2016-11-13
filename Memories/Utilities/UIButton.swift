//
//  UIButton.swift
//  Memories
//
//  Created by Michael Brown on 11/11/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import UIKit

extension UIButton {
    static func circlePlayButton(diameter: CGFloat) -> UIButton {
        let button = UIButton(type: .custom)
        button.frame = CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))
        
        let circleImageNormal = CAShapeLayer.circlePlayShape(fillColor: .white, diameter: diameter).toImage()
        button.setImage(circleImageNormal, for: .normal)
        
        let circleImageHighlighted = CAShapeLayer.circlePlayShape(fillColor: .lightGray, diameter: diameter).toImage()
        button.setImage(circleImageHighlighted, for: .highlighted)
        
        return button
    }
}
