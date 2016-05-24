//
//  PhotoViewPresentTransition.swift
//  Memories
//
//  Created by Michael Brown on 10/12/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit
import AVFoundation

class PhotoViewPresentTransition: NSObject, UIViewControllerAnimatedTransitioning {
    let sourceImageView : UIImageView
    let duration = NSTimeInterval(0.25)
    let buttonOffset = CGFloat(50)
    
    init(sourceImageView: UIImageView) {
        self.sourceImageView = sourceImageView
    }
    
    // MARK: UIViewControllerAnimatedTransitioning
    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return duration
    }
    
    func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        guard let container = transitionContext.containerView(),
            toViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey),
            toView = transitionContext.viewForKey(UITransitionContextToViewKey) else {
            return
        }
        
        toView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        
        let transitionView = UIView(frame: transitionContext.finalFrameForViewController(toViewController))
        transitionView.backgroundColor = UIColor.clearColor()
        container.addSubview(transitionView)
        
        let imageViewFrameInOurCoordinateSystem = CGRectIntegral(transitionView.convertRect(self.sourceImageView.bounds, fromView: self.sourceImageView))
        let imageView = UIImageView(frame: imageViewFrameInOurCoordinateSystem)
        imageView.image = sourceImageView.image
        imageView.contentMode = container.thumbnailContentMode
        imageView.clipsToBounds = true
        transitionView.addSubview(imageView)

        container.addSubview(toView)
        toView.alpha = 0.0
        self.sourceImageView.hidden = true
        
        let fullImageViewSize = AVMakeRectWithAspectRatioInsideRect(sourceImageView.image!.size, CGRect(origin: CGPointZero, size: transitionView.frame.size)).size
        let newImageViewSize = adjustImageBoundsForButtons(fullImageViewSize, vcViewSize: transitionView.frame.size)
        
        UIView.animateKeyframesWithDuration(duration, delay: 0, options: .CalculationModeLinear, animations: {
            UIView.addKeyframeWithRelativeStartTime(0, relativeDuration: 0.75) {
                transitionView.backgroundColor = UIColor.blackColor()
                imageView.bounds = CGRect(origin: CGPointZero, size: newImageViewSize)
                imageView.center = transitionView.center
            }
            
            UIView.addKeyframeWithRelativeStartTime(0.75, relativeDuration: 0.25) {
                toView.alpha = 1.0
            }
        }) { finished in
            self.sourceImageView.hidden = false
            transitionView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
        }        
    }
    
    private func adjustImageBoundsForButtons(imageViewSize: CGSize, vcViewSize: CGSize) -> CGSize {
        let hPadding = floor((vcViewSize.width - imageViewSize.width) / 2)
        let vPadding = floor((vcViewSize.height - imageViewSize.height) / 2)
        
        if vPadding < buttonOffset && hPadding < buttonOffset {
            let scale: CGFloat
            let padDim: CGFloat
            let imageDim: CGFloat
            
            if hPadding > vPadding {
                imageDim = imageViewSize.width
                padDim = hPadding
            } else if vPadding > hPadding {
                imageDim = imageViewSize.height
                padDim = vPadding
            } else { // vPadding == hPadding
                if imageViewSize.height > imageViewSize.width {
                    imageDim = imageViewSize.height
                    padDim = vPadding
                } else {
                    imageDim = imageViewSize.width
                    padDim = hPadding
                }
            }
            
            scale = (imageDim - ((buttonOffset - padDim) * 2)) / imageDim
            
            return CGSizeApplyAffineTransform(imageViewSize, CGAffineTransformMakeScale(scale, scale))
        }
        
        return imageViewSize
    }
}
