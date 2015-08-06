//
//  ZoomingPhotoView.swift
//  Memories
//
//  Created by Michael Brown on 26/07/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit
import Photos
import Cartography
import DACircularProgress

class ZoomingPhotoView: UIScrollView, UIScrollViewDelegate {

    var imageRequestId : PHImageRequestID?
    var imageView : UIImageView!
    var progressView : DACircularProgressView!
    var displayLink : CADisplayLink!
    var bounceScale : CGFloat = 0.0
    
    var imageConstraintTop : NSLayoutConstraint!
    var imageConstraintBottom : NSLayoutConstraint!
    var imageConstraintLeft : NSLayoutConstraint!
    var imageConstraintRight : NSLayoutConstraint!

    var lastZoomScale : CGFloat = -1
    var progressConstraintGroup : ConstraintGroup!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.delegate = self

        imageView = UIImageView()
        imageView.userInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(self.imageView)
    
        let hConstraints = NSLayoutConstraint.constraintsWithVisualFormat("H:|[imageView]|", options: NSLayoutFormatOptions(rawValue: 0)
            , metrics: nil, views: ["imageView": imageView!])
        let vConstraints = NSLayoutConstraint.constraintsWithVisualFormat("V:|[imageView]|", options: NSLayoutFormatOptions(rawValue: 0)
            , metrics: nil, views: ["imageView": imageView!])
        addConstraints(hConstraints)
        addConstraints(vConstraints)
        
        imageConstraintTop = vConstraints[0]
        imageConstraintBottom = vConstraints[1]
        imageConstraintLeft = hConstraints[0]
        imageConstraintRight = hConstraints[1]
        
        displayLink = CADisplayLink(target: self, selector: "displayLinkTick")
        displayLink.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        
        progressView = DACircularProgressView()
        progressView.roundedCorners = Int(false)
        progressView.thicknessRatio = 1
        progressView.trackTintColor = UIColor.clearColor()
        progressView.layer.borderColor = UIColor.whiteColor().CGColor
        progressView.layer.borderWidth = 1
        progressView.layer.cornerRadius = 10;
        progressView.hidden = true
        addSubview(progressView)
        
        constrain(self, progressView) {view, progressView in
            progressView.width == 20
            progressView.height == 20
        }
        
        progressConstraintGroup = constrain(self, progressView) {view, progressView in
            progressView.top == view.top
            progressView.left == view.left
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(frame: CGRectZero)
    }
    
    
    var image : UIImage? {
        didSet {
            imageView.image = self.image
            adjustZoomScale()
        }
    }
    
    
    // MARK: Implementation
    func displayLinkTick() {
        let zoomedLayer =  imageView.layer.presentationLayer()!
        bounceScale = zoomedLayer.transform.m11
        
        if bounceScale < minimumZoomScale {
            updateConstraints()
        }
    }
    
    func updateProgress(progress: Double) {
        progressView.hidden = (progress <= 0.0 || progress >= 1.0)
        progressView.setProgress(CGFloat(progress), animated: true)
    }
    
    func adjustZoomScale() {
        // adjust sizes as necessary
        if let image = self.image {
            var minZoom = min(bounds.size.width / image.size.width,
                bounds.size.height / image.size.height) + 0.001;
            
            minimumZoomScale = minZoom
            maximumZoomScale = minZoom * 2
            bounceScale = minimumZoomScale
            
            // Force scrollViewDidZoom fire if zoom did not change
            if minZoom == lastZoomScale { minZoom += 0.000001 }
            
            zoomScale = minZoom
            lastZoomScale = minZoom
        }
    }
    
    // MARK: UIView
    
    override func updateConstraints() {
        
        if let image = imageView.image {
            let imageWidth = image.size.width
            let imageHeight = image.size.height
            
            let boundsSize = bounds.size
            let viewWidth = boundsSize.width
            let viewHeight = boundsSize.height
            
            let scale = bounceScale < minimumZoomScale ? bounceScale : zoomScale
            
            // center image if it is smaller than screen
            var hPadding = (viewWidth - scale * imageWidth) / 2
            if hPadding < 0 { hPadding = 0 }
            
            var vPadding = (viewHeight - scale * imageHeight) / 2
            if vPadding < 0 { vPadding = 0 }
            
            imageConstraintLeft.constant = hPadding
            imageConstraintRight.constant = hPadding
            
            imageConstraintTop.constant = vPadding
            imageConstraintBottom.constant = vPadding

            constrain(self, progressView, replace: progressConstraintGroup) {view, progressView in
                progressView.top == view.top + vPadding + (scale * imageHeight) - 25
                progressView.left == view.left + hPadding + (scale * imageWidth) - 25
            }
            
//            print("imageWidth: \(imageWidth), imageHeight: \(imageHeight), hPadding: \(hPadding), vPadding: \(vPadding), bounceScale: \(bounceScale), zoomScale: \(zoomScale)")
        }

        super.updateConstraints()
    }
    
    func scrollViewDidZoom(scrollView: UIScrollView) {
        if zoomScale < minimumZoomScale {
            bounceScale = zoomScale
        } else if !zoomBouncing {
            bounceScale = minimumZoomScale
        }
        updateConstraints()
    }
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return imageView;
    }
    
}
