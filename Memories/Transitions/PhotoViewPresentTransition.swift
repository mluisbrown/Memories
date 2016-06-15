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
    let duration = TimeInterval(0.25)
    let buttonOffset = CGFloat(50)
    
    init(sourceImageView: UIImageView) {
        self.sourceImageView = sourceImageView
    }
    
    // MARK: UIViewControllerAnimatedTransitioning
    func transitionDuration(_ transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    func animateTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        guard let toViewController = transitionContext.viewController(forKey: UITransitionContextToViewControllerKey),
            toView = transitionContext.view(forKey: UITransitionContextToViewKey) else {
            return
        }
        let container = transitionContext.containerView()
        toView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        let transitionView = UIView(frame: transitionContext.finalFrame(for: toViewController))
        transitionView.backgroundColor = UIColor.clear()
        container.addSubview(transitionView)
        
        let imageViewFrameInOurCoordinateSystem = transitionView.convert(self.sourceImageView.bounds, from: self.sourceImageView).integral
        let imageView = UIImageView(frame: imageViewFrameInOurCoordinateSystem)
        imageView.image = sourceImageView.image
        imageView.contentMode = container.thumbnailContentMode
        imageView.clipsToBounds = true
        transitionView.addSubview(imageView)

        container.addSubview(toView)
        toView.alpha = 0.0
        self.sourceImageView.isHidden = true
        
        let fullImageViewSize = AVMakeRect(aspectRatio: sourceImageView.image!.size, insideRect: CGRect(origin: CGPoint.zero, size: transitionView.frame.size)).size
        let newImageViewSize = adjustImageBoundsForButtons(fullImageViewSize, vcViewSize: transitionView.frame.size)
        
        UIView.animateKeyframes(withDuration: duration, delay: 0, options: UIViewKeyframeAnimationOptions(), animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.75) {
                transitionView.backgroundColor = UIColor.black()
                imageView.bounds = CGRect(origin: CGPoint.zero, size: newImageViewSize)
                imageView.center = transitionView.center
            }
            
            UIView.addKeyframe(withRelativeStartTime: 0.75, relativeDuration: 0.25) {
                toView.alpha = 1.0
            }
        }) { finished in
            self.sourceImageView.isHidden = false
            transitionView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
        }        
    }
    
    private func adjustImageBoundsForButtons(_ imageViewSize: CGSize, vcViewSize: CGSize) -> CGSize {
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
            
            return imageViewSize.apply(transform: CGAffineTransform(scaleX: scale, y: scale))
        }
        
        return imageViewSize
    }
}
