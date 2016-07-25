
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
    let transitionDuration = TimeInterval(0.25)
    
    var panHeight = CGFloat(0)
    
    init(destImageView: UIImageView, sourceImageView: UIImageView) {
        self.destImageView = destImageView
        self.sourceImageView = sourceImageView
    }
    
    // MARK: UIViewControllerAnimatedTransitioning
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return transitionDuration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromViewController = transitionContext.viewController(forKey: UITransitionContextFromViewControllerKey),
            let toViewController = transitionContext.viewController(forKey: UITransitionContextToViewControllerKey),
            let fromView = transitionContext.view(forKey: UITransitionContextFromViewKey) else {
                transitionContext.completeTransition(false)
                return
        }
        
        let statusBarVc = toViewController.statusBarContoller()
        
        let container = transitionContext.containerView()
        let transitionView = UIView(frame: transitionContext.initialFrame(for: fromViewController))
        transitionView.backgroundColor = UIColor.black()
        container.insertSubview(transitionView, belowSubview: fromView)
        
        let startImageFrame = transitionView.convert(self.sourceImageView.bounds, from: self.sourceImageView).integral
        let imageView = UIImageView(frame: startImageFrame)
        imageView.image = destImageView.image
        imageView.contentMode = container.thumbnailContentMode
        imageView.clipsToBounds = true
        transitionView.addSubview(imageView)
        
        let fromBackgroundColor = fromView.backgroundColor
        fromView.backgroundColor = UIColor.clear()
        self.destImageView.isHidden = true
        self.sourceImageView.isHidden = true        
        
        UIView.animateKeyframes(withDuration: transitionDuration, delay: 0, options: UIViewKeyframeAnimationOptions(), animations: {
            statusBarVc?.hideStatusBar(false)
            let newImageFrame = transitionView.convert(self.destImageView.bounds, from: self.destImageView).integral

            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.25) {
                fromView.alpha = 0.001
            }
            
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                imageView.frame = newImageFrame
                transitionView.backgroundColor = UIColor.clear()
            }
        }) { finished in
            self.destImageView.isHidden = false
            
            let cancelled = transitionContext.transitionWasCancelled()
            
            if cancelled {
                statusBarVc?.hideStatusBar(true)
                fromView.backgroundColor = fromBackgroundColor
                self.destImageView.isHidden = false
                self.sourceImageView.isHidden = false
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
        case .began:
            let startPoint = gr.location(in: gr.view)
            panHeight = gr.view!.bounds.height - startPoint.y
        case .changed:
            let percent = gr.translation(in: gr.view).y / panHeight
            update (percent <= 0 ? 0 : percent)
        case .ended, .cancelled:
            let velocity = gr.velocity(in: gr.view)
            if velocity.y < 0 || gr.state == .cancelled {
                cancel()
            }
            else {
                finish()
            }
        default:
            break
        }
    }
}
