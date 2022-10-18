import UIKit
import QuartzCore

extension CAShapeLayer {
    
    public static func circlePlayShape(fillColor: UIColor, diameter: CGFloat) -> CAShapeLayer {
        let frame = CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))
        let circle = CAShapeLayer()
        circle.frame = frame
        
        let circlePath = UIBezierPath(ovalIn: frame)
        let trainglePath = UIBezierPath(triangleOfSide: diameter / 2, offset: CGPoint(x: diameter / 3, y: diameter / 4))
        circlePath.append(trainglePath)

        circle.path = circlePath.cgPath
        circle.fillColor = fillColor.cgColor
        
        return circle
    }

    public static func circle(fillColor: UIColor, diameter: CGFloat) -> CAShapeLayer {
        let circle = CAShapeLayer()
        let frame = CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))
        circle.frame = frame
        circle.path = UIBezierPath(ovalIn: frame).cgPath
        circle.fillColor = fillColor.cgColor
        
        return circle
    }
}
