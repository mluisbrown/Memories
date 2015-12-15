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
        let container = transitionContext.containerView()!
        let toViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!
        let fromViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)!
        
        let transitionView = UIView(frame: transitionContext.finalFrameForViewController(toViewController))
        transitionView.backgroundColor = UIColor.clearColor()
        container.insertSubview(transitionView, belowSubview: fromViewController.view)
        
        let startImageFrame = CGRectIntegral(transitionView.convertRect(self.sourceImageView.bounds, fromView: self.sourceImageView))
        let imageView = UIImageView(frame: startImageFrame)
        imageView.image = destImageView.image
        imageView.contentMode = .ScaleAspectFill
        imageView.clipsToBounds = true
        transitionView.addSubview(imageView)
        
        toViewController.view.alpha = 0.0
        fromViewController.view.backgroundColor = UIColor.clearColor()
        self.destImageView.hidden = true
        self.sourceImageView.hidden = true
        
        let newImageFrame = CGRectIntegral(transitionView.convertRect(self.destImageView.bounds, fromView: self.destImageView))
        
        UIView.animateKeyframesWithDuration(duration, delay: 0, options: .CalculationModeLinear, animations: {
            UIView.addKeyframeWithRelativeStartTime(0.0, relativeDuration: 0.25) {
                fromViewController.view.alpha = 0.0
            }
            
            UIView.addKeyframeWithRelativeStartTime(0, relativeDuration: 1) {
                imageView.frame = newImageFrame
                toViewController.view.alpha = 1.0
            }
        }) { finished in
            self.destImageView.hidden = false
            fromViewController.view.removeFromSuperview()
            
            transitionView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
        }        
    }    
}
