import UIKit

extension UIButton {
    public static func circlePlayButton(diameter: CGFloat) -> UIButton {
        let button = UIButton(type: .custom)
        button.frame = CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))
        
        let circleImageNormal = CAShapeLayer.circlePlayShape(fillColor: .white, diameter: diameter).toImage()
        button.setImage(circleImageNormal, for: .normal)
        
        let circleImageHighlighted = CAShapeLayer.circlePlayShape(fillColor: .lightGray, diameter: diameter).toImage()
        button.setImage(circleImageHighlighted, for: .highlighted)
        
        return button
    }
}
