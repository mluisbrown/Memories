
//  PhotoViewSwipeDismissTransition.swift
//  Memories
//
//  Created by Michael Brown on 11/06/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import UIKit

class PhotoViewSwipeDismissTransition:
    UIPercentDrivenInteractiveTransition,
    UIViewControllerAnimatedTransitioning {
    let destImageView: UIImageView
    let sourceImageView: UIImageView
    let transitionDuration = NSTimeInterval(0.25)
    
    var panHeight = CGFloat(0)
    
    init(destImageView: UIImageView, sourceImageView: UIImageView) {
        self.destImageView = destImageView
        self.sourceImageView = sourceImageView
    }
    
    // MARK: UIViewControllerAnimatedTransitioning
    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return transitionDuration
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
        imageView.contentMode = container.thumbnailContentMode
        imageView.clipsToBounds = true
        transitionView.addSubview(imageView)
        
        let fromBackgroundColor = fromView.backgroundColor
        fromView.backgroundColor = UIColor.clearColor()
        self.destImageView.hidden = true
        self.sourceImageView.hidden = true
        
        let newImageFrame = CGRectIntegral(transitionView.convertRect(self.destImageView.bounds, fromView: self.destImageView))
        
        UIView.animateKeyframesWithDuration(transitionDuration, delay: 0, options: .CalculationModeLinear, animations: {
            UIView.addKeyframeWithRelativeStartTime(0.0, relativeDuration: 0.25) {
                fromView.alpha = 0.0
            }
            
            UIView.addKeyframeWithRelativeStartTime(0, relativeDuration: 1) {
                imageView.frame = newImageFrame
                transitionView.backgroundColor = UIColor.clearColor()
            }
        }) { finished in
            self.destImageView.hidden = false
            
            let cancelled = transitionContext.transitionWasCancelled()
            
            if cancelled {
                fromView.backgroundColor = fromBackgroundColor
                self.destImageView.hidden = false
                self.sourceImageView.hidden = false
            }
            else {
                fromView.removeFromSuperview()
            }
            
            transitionView.removeFromSuperview()
            transitionContext.completeTransition(!cancelled)
        }
    }
    
    // MARK: gesture handling
    func handlePan(panRecognizer gr: UIPanGestureRecognizer) {
        switch gr.state {
        case .Began:
            let startPoint = gr.locationInView(gr.view)
            panHeight = gr.view!.bounds.height - startPoint.y
        case .Changed:
            let percent = gr.translationInView(gr.view).y / panHeight
            updateInteractiveTransition(percent <= 0 ? 0 : percent)
        case .Ended, .Cancelled:
            let velocity = gr.velocityInView(gr.view)
            if velocity.y < 0 || gr.state == .Cancelled {
                cancelInteractiveTransition()
            }
            else {
                finishInteractiveTransition()
            }
        default:
            break
        }
    }
}
