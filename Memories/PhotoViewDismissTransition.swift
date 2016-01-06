//
//  PhotoViewDismissTransition.swift
//  Memories
//
//  Created by Michael Brown on 11/12/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit
import AVFoundation

class PhotoViewDismissTransition: NSObject, UIViewControllerAnimatedTransitioning {
    
    let destImageView: UIImageView
    let sourceImageView: UIImageView
    let duration = NSTimeInterval(0.5)

    init(destImageView: UIImageView, sourceImageView: UIImageView) {
        self.destImageView = destImageView
        self.sourceImageView = sourceImageView
    }
    
    // MARK: UIViewControllerAnimatedTransitioning
    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return duration
    }
    
    func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        guard let container = transitionContext.containerView(),
            fromViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey),
            fromView = transitionContext.viewForKey(UITransitionContextFromViewKey) else {
                transitionContext.completeTransition(false)
                return
        }
        
        let transitionView = UIView(frame: transitionContext.initialFrameForViewController(fromViewController))
        transitionView.backgroundColor = UIColor.blackColor()
        container.insertSubview(transitionView, belowSubview: fromView)
        
        let startImageFrame = CGRectIntegral(transitionView.convertRect(self.sourceImageView.bounds, fromView: self.sourceImageView))
        let imageView = UIImageView(frame: startImageFrame)
        imageView.image = destImageView.image
        imageView.contentMode = .ScaleAspectFill
        imageView.clipsToBounds = true
        transitionView.addSubview(imageView)
        
        fromView.backgroundColor = UIColor.clearColor()
        self.destImageView.hidden = true
        self.sourceImageView.hidden = true
        
        let newImageFrame = CGRectIntegral(transitionView.convertRect(self.destImageView.bounds, fromView: self.destImageView))
        
        UIView.animateKeyframesWithDuration(duration, delay: 0, options: .CalculationModeLinear, animations: {
            UIView.addKeyframeWithRelativeStartTime(0.0, relativeDuration: 0.25) {
                fromView.alpha = 0.0
            }
            
            UIView.addKeyframeWithRelativeStartTime(0, relativeDuration: 1) {
                imageView.frame = newImageFrame
                transitionView.backgroundColor = UIColor.clearColor()
            }
        }) { finished in
            self.destImageView.hidden = false
            fromView.removeFromSuperview()
            
            transitionView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
        }        
    }    
}
