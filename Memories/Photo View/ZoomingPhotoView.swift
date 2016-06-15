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
    func hideControls(_ hide: Bool)
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
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(self.imageView)
    
        let hConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[imageView]|", options: NSLayoutFormatOptions(rawValue: 0)
            , metrics: nil, views: ["imageView": imageView!])
        let vConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[imageView]|", options: NSLayoutFormatOptions(rawValue: 0)
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
        progressView.trackTintColor = UIColor.clear()
        progressView.layer.borderColor = UIColor.white().cgColor
        progressView.layer.borderWidth = 1
        progressView.layer.cornerRadius = 10;
        progressView.isHidden = true
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
        errorIndicator.textAlignment = .center
        errorIndicator.font = UIFont.boldSystemFont(ofSize: 14)
        errorIndicator.textColor = UIColor.white()
        errorIndicator.backgroundColor = UIColor.black().withAlphaComponent(0.1)
        errorIndicator.isHidden = true
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
        
        singleTapper.require(toFail: doubleTapper)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(frame: CGRect.zero)
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
                errorIndicator.isHidden = false
                progressView.isHidden = false
                progressView.setProgress(0.0, animated: false)
            }
        }
    }
    
    var imageIsDegraded : Bool = true {
        didSet {
            progressView.isHidden = !self.imageIsDegraded
        }
    }
    
    override var frame : CGRect {
        didSet {
            adjustZoomScale()
        }
    }
    
    // MARK: Implementation

    func hideProgressView(_ hide: Bool) {
        progressView.isHidden = hide
    }
    
    func updateProgress(_ progress: Double) {
        progressView.isHidden = progress >= 1.0
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
            isScrollEnabled = zoomScale >= minZoom
            
            adjustImageConstraintsForZoomScale(zoomScale)
        }
    }
    
    // MARK: UIView
    
    override func updateConstraints() {
        adjustImageConstraintsForZoomScale(zoomScale)
    
        super.updateConstraints()
    }
    
    private func getImagePadding(_ scale: CGFloat) -> (hPadding: CGFloat, vPadding: CGFloat)? {
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
    
    
    private func adjustImageConstraintsForZoomScale(_ scale: CGFloat) {
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
    func imageDoubleTapped(_ recognizer: UITapGestureRecognizer) {
        let touchPoint = recognizer.location(ofTouch: 0, in: imageView)

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

    func imageSingleTapped(_ recognizer: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.25) {
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
    
    private func zoomToScale(_ scale: CGFloat, center: CGPoint, animated: Bool) {
        let rect = zoomRect(forScale: scale, center: center)

        adjustImageConstraintsForZoomScale(scale)
        UIView.animate(withDuration: 0.5) {
            self.zoom(to: rect, animated: false)
            self.layoutIfNeeded()
        }
    }
    
    private func zoomToScale(_ scale: CGFloat, animated: Bool) {
        adjustImageConstraintsForZoomScale(scale)
        UIView.animate(withDuration: animated ? 0.5 : 0) {
            self.setZoomScale(scale, animated: false)
            self.layoutIfNeeded()
        }
    }
    
    
    // MARK: UIScrollViewDelegate
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        isScrollEnabled = zoomScale >= minimumZoomScale
        
        if zoomScale > minimumZoomScale {
            UIView.animate(withDuration: 0.25) {
                self.photoViewDelegate?.hideControls(true)
            }
        }
        
        adjustImageConstraintsForZoomScale(zoomScale)
        layoutIfNeeded()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView;
    }
    
}
