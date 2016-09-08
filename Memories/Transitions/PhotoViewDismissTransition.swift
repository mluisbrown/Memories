//
//  PhotoViewDismissTransition.swift
//  Memories
//
//  Created by Michael Brown on 11/12/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit

class PhotoViewDismissTransition: NSObject, UIViewControllerAnimatedTransitioning {
    
    let destImageView: UIImageView
    let sourceImageView: UIImageView
    let duration = TimeInterval(0.25)

    init(destImageView: UIImageView, sourceImageView: UIImageView) {
        self.destImageView = destImageView
        self.sourceImageView = sourceImageView
    }
    
    // MARK: UIViewControllerAnimatedTransitioning
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from),
            let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to),
            let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from) else {
                transitionContext.completeTransition(false)
                return
        }

        let container = transitionContext.containerView
        let transitionView = UIView(frame: transitionContext.initialFrame(for: fromViewController))
        transitionView.backgroundColor = fromView.backgroundColor
        container.insertSubview(transitionView, belowSubview: fromView)
        
        let startImageFrame = self.sourceImageView.frame
        let imageView = UIImageView(frame: startImageFrame)
        imageView.image = destImageView.image
        imageView.contentMode = container.thumbnailContentMode
        imageView.clipsToBounds = true
        transitionView.addSubview(imageView)
        
        fromView.backgroundColor = UIColor.clear
        self.destImageView.isHidden = true
        self.sourceImageView.isHidden = true
        
        UIView.animateKeyframes(withDuration: duration, delay: 0, options: UIViewKeyframeAnimationOptions(), animations: {
            toViewController.statusBarContoller()?.hideStatusBar(false)
            let newImageFrame = transitionView.convert(self.destImageView.bounds, from: self.destImageView).integral

            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.25) {
                fromView.alpha = 0.0
            }
            
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                imageView.frame = newImageFrame
                transitionView.backgroundColor = UIColor.clear
            }
        }) { finished in
            self.destImageView.isHidden = false
            fromView.removeFromSuperview()
            
            transitionView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }        
    }    
}
