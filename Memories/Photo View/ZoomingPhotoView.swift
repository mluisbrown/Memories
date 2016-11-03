//
//  ZoomingPhotoView.swift
//  Memories
//
//  Created by Michael Brown on 26/07/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit
import Photos
import PhotosUI
import Cartography
import DACircularProgress

protocol ZoomingPhotoViewDelegate {
    func hideControls(_ hide: Bool)
    func toggleControlsHidden()
}

class ZoomingPhotoView: UIScrollView, UIScrollViewDelegate {

    var imageRequestId : PHImageRequestID?
    var photoView = PhotoView()
    var progressView = DACircularProgressView()
    var errorIndicator = UILabel()
    
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
        
        photoView.isUserInteractionEnabled = true
        photoView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(self.photoView)
    
        let hConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[imageView]|", options: NSLayoutFormatOptions(rawValue: 0)
            , metrics: nil, views: ["imageView": photoView])
        let vConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[imageView]|", options: NSLayoutFormatOptions(rawValue: 0)
            , metrics: nil, views: ["imageView": photoView])
        addConstraints(hConstraints)
        addConstraints(vConstraints)
        
        imageConstraintTop = vConstraints[0]
        imageConstraintBottom = vConstraints[1]
        imageConstraintLeft = hConstraints[0]
        imageConstraintRight = hConstraints[1]
        
        progressView.roundedCorners = Int(false)
        progressView.thicknessRatio = 1
        progressView.trackTintColor = UIColor.clear
        progressView.layer.borderColor = UIColor.white.cgColor
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
        
        errorIndicator.text = "!"
        errorIndicator.textAlignment = .center
        errorIndicator.font = UIFont.boldSystemFont(ofSize: 14)
        errorIndicator.textColor = UIColor.white
        errorIndicator.backgroundColor = UIColor.black.withAlphaComponent(0.1)
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
    
    var photo : UIImage? {
        didSet {
            photoView.photo = photo
            adjustZoomScale()
        }
    }
    
    var livePhoto: PHLivePhoto? {
        didSet {
            photoView.livePhoto = livePhoto
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

    func didBecomeVisible() {
        photoView.didBecomeVisible()
    }
    
    func hideProgressView(_ hide: Bool) {
        progressView.isHidden = hide
    }
    
    func updateProgress(_ progress: Double) {
        progressView.isHidden = progress >= 1.0
        progressView.setProgress(CGFloat(progress), animated: true)
    }
    
    private func adjustZoomScale() {
        // adjust sizes as necessary
        if let imageSize = photoView.imageSize {
            var minZoom = min(bounds.size.width / imageSize.width,
                              bounds.size.height / imageSize.height);
            
            aspectFitZoomScale = minZoom
            
            let padding = getImagePadding(for: minZoom)!
            if padding.hPadding < buttonOffset && padding.vPadding < buttonOffset {
                let viewDim : CGFloat
                let imageDim : CGFloat
                if padding.hPadding > padding.vPadding {
                    viewDim = bounds.size.width
                    imageDim = imageSize.width
                } else {
                    viewDim = bounds.size.height
                    imageDim = imageSize.height
                }
                
                let adjustedScale = abs((2 * buttonOffset - viewDim) / imageDim)
                minZoom = adjustedScale
            }
            
            minimumZoomScale = minZoom
            maximumZoomScale = minZoom * 4
            zoomScale = minZoom
            
            // only allow scrolling if the image has been zoomed
            // larger than the window
            isScrollEnabled = zoomScale > minZoom
            
            adjustImageConstraints(for: zoomScale)
        }
    }
    
    // MARK: UIView
    
    override func updateConstraints() {
        adjustImageConstraints(for: zoomScale)
    
        super.updateConstraints()
    }
    
    private func getImagePadding(for scale: CGFloat) -> (hPadding: CGFloat, vPadding: CGFloat)? {
        guard let imageSize = photoView.imageSize else {
            return nil
        }
        
        let imageWidth = imageSize.width
        let imageHeight = imageSize.height
        
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
    
    
    private func adjustImageConstraints(for zoomScale: CGFloat) {
        guard let padding = getImagePadding(for: zoomScale),
                  let imageSize = photoView.imageSize else {
            return
        }

        let hPadding = padding.hPadding
        let vPadding = padding.vPadding
        let imageWidth = imageSize.width
        let imageHeight = imageSize.height
        
        imageConstraintLeft.constant = hPadding
        imageConstraintRight.constant = hPadding
        
        imageConstraintTop.constant = vPadding
        imageConstraintBottom.constant = vPadding
        
        constrain(self, progressView, replace: progressConstraintGroup) {view, progressView in
            progressView.top == view.top + vPadding + (zoomScale * imageHeight) - 25
            progressView.left == view.left + hPadding + (zoomScale * imageWidth) - 25
        }
    }
    
    // MARK: UITapGestureRecognizer actions
    func imageDoubleTapped(_ recognizer: UITapGestureRecognizer) {
        let touchPoint = recognizer.location(ofTouch: 0, in: photoView)

        if zoomScale < aspectFitZoomScale {
            zoom(to: aspectFitZoomScale, animated: true)
        }
        else if zoomScale == minimumZoomScale ||
            zoomScale == aspectFitZoomScale {
            zoom(to: zoomScale * 3, center: touchPoint, animated: true)
        }
        else {
            zoom(to: minimumZoomScale, animated: true)
        }
    }

    func imageSingleTapped(_ recognizer: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.25) {
            self.photoViewDelegate?.toggleControlsHidden()
        }
    }
    
    private func zoomRect(for scale: CGFloat, center: CGPoint) -> CGRect {
        let width = frame.size.width  / scale
        let height = frame.size.height / scale
        let originX = center.x - (width / 2.0)
        let originY = center.y - (height / 2.0)
        
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
    
    private func zoom(to scale: CGFloat, center: CGPoint, animated: Bool) {
        let rect = zoomRect(for: scale, center: center)

        adjustImageConstraints(for: scale)
        UIView.animate(withDuration: 0.5) {
            self.zoom(to: rect, animated: false)
            self.layoutIfNeeded()
        }
    }
    
    private func zoom(to scale: CGFloat, animated: Bool) {
        adjustImageConstraints(for: scale)
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
        
        adjustImageConstraints(for: zoomScale)
        layoutIfNeeded()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return photoView;
    }
    
}
