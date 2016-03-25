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
    var errorIndicator : UILabel!
    
    var displayLink : CADisplayLink!
    var bounceScale : CGFloat = 0.0
    
    var imageConstraintTop : NSLayoutConstraint!
    var imageConstraintBottom : NSLayoutConstraint!
    var imageConstraintLeft : NSLayoutConstraint!
    var imageConstraintRight : NSLayoutConstraint!

    var lastZoomScale : CGFloat = -1
    var progressConstraintGroup : ConstraintGroup!
    
    var doubleTapper: UITapGestureRecognizer!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.delegate = self

        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = false
        self.bounces = false
        
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
        
        displayLink = CADisplayLink(target: self, selector: #selector(ZoomingPhotoView.displayLinkTick))
        displayLink.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        displayLink.paused = true
        
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
        
        errorIndicator = UILabel()
        errorIndicator.text = "!"
        errorIndicator.textAlignment = .Center
        errorIndicator.font = UIFont.boldSystemFontOfSize(14)
        errorIndicator.textColor = UIColor.whiteColor()
        errorIndicator.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.1)
        errorIndicator.hidden = true
        progressView.addSubview(errorIndicator)
        
        constrain(errorIndicator, progressView) {errorView, progressView in
            align(top: errorView, progressView)
            align(bottom: errorView, progressView)
            align(left: errorView, progressView)
            align(right: errorView, progressView)
        }
        
        doubleTapper = UITapGestureRecognizer(target: self, action: #selector(ZoomingPhotoView.imageDoubleTapped(_:)))
        doubleTapper.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTapper)
    }

    deinit {
        displayLink.invalidate()
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
    
    var fullImageUnavailable : Bool = false {
        didSet {
            if self.fullImageUnavailable {
                errorIndicator.hidden = false
                progressView.hidden = false
                progressView.setProgress(0.0, animated: false)
            }
        }
    }
    
    var imageIsDegraded : Bool = true {
        didSet {
            progressView.hidden = !self.imageIsDegraded
        }
    }
    
    override var frame : CGRect {
        didSet {
            adjustZoomScale()
        }
    }
    
    // MARK: Implementation

    func hideProgressView(hide: Bool) {
        progressView.hidden = hide
    }
    
    func displayLinkTick() {
        if let zoomedLayer = imageView.layer.presentationLayer() {
            bounceScale = zoomedLayer.transform.m11
            
            if bounceScale < minimumZoomScale {
                updateConstraints()
            }
        }
    }
    
    func updateProgress(progress: Double) {
        progressView.hidden = progress >= 1.0
        progressView.setProgress(CGFloat(progress), animated: true)
    }
    
    func adjustZoomScale() {
        // adjust sizes as necessary
        if let image = self.image {
            let minZoom = min(bounds.size.width / image.size.width,
                bounds.size.height / image.size.height);
            
            minimumZoomScale = minZoom
            maximumZoomScale = minZoom * 4
            bounceScale = minimumZoomScale
            
            zoomScale = minZoom
            lastZoomScale = minZoom
            
            // only allow scrolling if the image has been zoomed
            // larger than the window
            scrollEnabled = zoomScale >= minZoom
            
            adjustImageConstraintsForZoomScale(zoomScale)
        }
    }
    
    // MARK: UIView
    
    override func updateConstraints() {
        let scale = bounceScale < minimumZoomScale ? bounceScale : zoomScale
        adjustImageConstraintsForZoomScale(scale)
    
        super.updateConstraints()
    }
    
    func adjustImageConstraintsForZoomScale(scale: CGFloat) {
        if let image = imageView.image {
            let imageWidth = image.size.width
            let imageHeight = image.size.height
            
            let boundsSize = bounds.size
            let viewWidth = boundsSize.width
            let viewHeight = boundsSize.height
            
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
        }
    }
    
    // UITapGestureRecognizer action
    func imageDoubleTapped(recognizer: UITapGestureRecognizer) {
        let touchPoint = recognizer.locationOfTouch(0, inView: imageView)
        
        if zoomScale == minimumZoomScale {
            let newScale = zoomScale * 3
            let zoomRect = self.zoomRect(forScale: newScale, center: touchPoint)
            
            adjustImageConstraintsForZoomScale(newScale)
            UIView.animateWithDuration(0.5) {
                self.zoomToRect(zoomRect, animated: false)
                self.layoutIfNeeded()
            }
        }
        else  {
            adjustImageConstraintsForZoomScale(minimumZoomScale)
            UIView.animateWithDuration(0.5) {
                self.setZoomScale(self.minimumZoomScale, animated: false)
                self.layoutIfNeeded()
            }
        }
    }
    
    private func zoomRect(forScale scale: CGFloat, center: CGPoint) -> CGRect {
        let width = frame.size.width  / scale
        let height = frame.size.height / scale
        let originX = center.x - (width / 2.0)
        let originY = center.y - (height / 2.0)
        
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
    
    
    // MARK: UIScrollViewDelegate
    
    func scrollViewDidZoom(scrollView: UIScrollView) {
        if zoomScale < minimumZoomScale {
            bounceScale = zoomScale
            displayLink.paused = false
        } else if !zoomBouncing {
            displayLink.paused = true
            bounceScale = minimumZoomScale
        }
        
        scrollEnabled = zoomScale >= minimumZoomScale
        updateConstraints()
    }
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return imageView;
    }
    
}
