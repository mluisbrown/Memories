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

protocol ZoomingPhotoViewDelegate {
    func hideControls(hide: Bool)
    func toggleControlsHidden()
}

class ZoomingPhotoView: UIScrollView, UIScrollViewDelegate {

    var imageRequestId : PHImageRequestID?
    var imageView : UIImageView!
    var progressView : DACircularProgressView!
    var errorIndicator : UILabel!
    
    var photoViewDelegate: ZoomingPhotoViewDelegate?
    
    var imageConstraintTop : NSLayoutConstraint!
    var imageConstraintBottom : NSLayoutConstraint!
    var imageConstraintLeft : NSLayoutConstraint!
    var imageConstraintRight : NSLayoutConstraint!

    var progressConstraintGroup : ConstraintGroup!
    
    var doubleTapper: UITapGestureRecognizer!
    var singleTapper: UITapGestureRecognizer!
    
    let buttonOffset = CGFloat(50)
    var aspectFitZoomScale = CGFloat(0)
    
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
        
        singleTapper = UITapGestureRecognizer(target: self, action: #selector(ZoomingPhotoView.imageSingleTapped(_:)))
        singleTapper.numberOfTapsRequired = 1
        self.addGestureRecognizer(singleTapper)
        
        singleTapper.requireGestureRecognizerToFail(doubleTapper)
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
    
    func updateProgress(progress: Double) {
        progressView.hidden = progress >= 1.0
        progressView.setProgress(CGFloat(progress), animated: true)
    }
    
    private func adjustZoomScale() {
        // adjust sizes as necessary
        if let image = self.image {
            var minZoom = min(bounds.size.width / image.size.width,
                              bounds.size.height / image.size.height);
            
            aspectFitZoomScale = minZoom
            
            let padding = getImagePadding(minZoom)!
            if padding.hPadding < buttonOffset && padding.vPadding < buttonOffset {
                let viewDim : CGFloat
                let imageDim : CGFloat
                if padding.hPadding > padding.vPadding {
                    viewDim = bounds.size.width
                    imageDim = image.size.width
                } else {
                    viewDim = bounds.size.height
                    imageDim = image.size.height
                }
                
                let adjustedScale = abs((2 * buttonOffset - viewDim) / imageDim)
                minZoom = adjustedScale
            }
            
            minimumZoomScale = minZoom
            maximumZoomScale = minZoom * 4
            zoomScale = minZoom
            
            // only allow scrolling if the image has been zoomed
            // larger than the window
            scrollEnabled = zoomScale >= minZoom
            
            adjustImageConstraintsForZoomScale(zoomScale)
        }
    }
    
    // MARK: UIView
    
    override func updateConstraints() {
        adjustImageConstraintsForZoomScale(zoomScale)
    
        super.updateConstraints()
    }
    
    private func getImagePadding(scale: CGFloat) -> (hPadding: CGFloat, vPadding: CGFloat)? {
        guard let image = imageView.image else {
            return nil
        }
        
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        
        let boundsSize = bounds.size
        let viewWidth = boundsSize.width
        let viewHeight = boundsSize.height
        
        // center image if it is smaller than screen
        var hPadding = floor((viewWidth - scale * imageWidth) / 2)
        if hPadding < 0 { hPadding = 0 }
        
        var vPadding = floor((viewHeight - scale * imageHeight) / 2)
        if vPadding < 0 { vPadding = 0 }
        
        return (hPadding, vPadding)
    }
    
    
    private func adjustImageConstraintsForZoomScale(scale: CGFloat) {
        guard let padding = getImagePadding(scale),
                  image = imageView.image else {
            return
        }

        let hPadding = padding.hPadding
        let vPadding = padding.vPadding
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        
        imageConstraintLeft.constant = hPadding
        imageConstraintRight.constant = hPadding
        
        imageConstraintTop.constant = vPadding
        imageConstraintBottom.constant = vPadding
        
        constrain(self, progressView, replace: progressConstraintGroup) {view, progressView in
            progressView.top == view.top + vPadding + (scale * imageHeight) - 25
            progressView.left == view.left + hPadding + (scale * imageWidth) - 25
        }
    }
    
    // MARK: UITapGestureRecognizer actions
    func imageDoubleTapped(recognizer: UITapGestureRecognizer) {
        let touchPoint = recognizer.locationOfTouch(0, inView: imageView)

        if zoomScale < aspectFitZoomScale {
            zoomToScale(aspectFitZoomScale, animated: true)
        }
        else if zoomScale == minimumZoomScale ||
            zoomScale == aspectFitZoomScale {
            zoomToScale(zoomScale * 3, center: touchPoint, animated: true)
        }
        else {
            zoomToScale(minimumZoomScale, animated: true)
        }
    }

    func imageSingleTapped(recognizer: UITapGestureRecognizer) {
        UIView.animateWithDuration(0.25) {
            self.photoViewDelegate?.toggleControlsHidden()
        }
    }
    
    private func zoomRect(forScale scale: CGFloat, center: CGPoint) -> CGRect {
        let width = frame.size.width  / scale
        let height = frame.size.height / scale
        let originX = center.x - (width / 2.0)
        let originY = center.y - (height / 2.0)
        
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
    
    private func zoomToScale(scale: CGFloat, center: CGPoint, animated: Bool) {
        let rect = zoomRect(forScale: scale, center: center)

        adjustImageConstraintsForZoomScale(scale)
        UIView.animateWithDuration(0.5) {
            self.zoomToRect(rect, animated: false)
            self.layoutIfNeeded()
        }
    }
    
    private func zoomToScale(scale: CGFloat, animated: Bool) {
        adjustImageConstraintsForZoomScale(scale)
        UIView.animateWithDuration(animated ? 0.5 : 0) {
            self.setZoomScale(scale, animated: false)
            self.layoutIfNeeded()
        }
    }
    
    
    // MARK: UIScrollViewDelegate
    
    func scrollViewDidZoom(scrollView: UIScrollView) {
        scrollEnabled = zoomScale >= minimumZoomScale
        
        if zoomScale > minimumZoomScale {
            UIView.animateWithDuration(0.25) {
                self.photoViewDelegate?.hideControls(true)
            }
        }
        
        adjustImageConstraintsForZoomScale(zoomScale)
        layoutIfNeeded()
    }
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return imageView;
    }
    
}
