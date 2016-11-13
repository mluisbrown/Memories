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
import AVFoundation
import Cartography
import DACircularProgress

protocol ZoomingPhotoViewDelegate {
    func viewWasZoomedIn()
    func viewWasTapped()
}

extension DACircularProgressView: LoadingSpinner {
    func show(loading: Bool) {
        if loading {
            isHidden = false
            indeterminate = 1
        } else {
            isHidden = true
            indeterminate = 0
        }
    }
}

class ZoomingPhotoView: UIScrollView, UIScrollViewDelegate {

    var imageRequestId : PHImageRequestID?

    let mediaView = MediaView().with {
        $0.isUserInteractionEnabled = true
        $0.translatesAutoresizingMaskIntoConstraints = false
    }
    
    let progressView = DACircularProgressView().with {
        $0.roundedCorners = Int(false)
        $0.thicknessRatio = 1
        $0.trackTintColor = UIColor.clear
        $0.layer.borderColor = UIColor.white.cgColor
        $0.layer.borderWidth = 1
        $0.layer.cornerRadius = 10;
        $0.isHidden = true
    }
    
    let errorIndicator = UILabel().with {
        $0.text = "!"
        $0.textAlignment = .center
        $0.font = UIFont.boldSystemFont(ofSize: 14)
        $0.textColor = UIColor.white
        $0.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        $0.isHidden = true
    }
    
    let videoLoadingSpinner = DACircularProgressView().with {
        $0.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        $0.thicknessRatio = 0.1
        $0.indeterminateDuration = 1
        $0.indeterminate = 0
        $0.isHidden = true
        $0.setProgress(0.33, animated: false)
    }
    
    let videoPlayButton = UIButton.circlePlayButton(diameter: 70).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }
    var playerController: PlayerController?
    
    var photoViewDelegate: ZoomingPhotoViewDelegate?
    
    var mediaConstraintGroup: ConstraintGroup?
    var progressConstraintGroup : ConstraintGroup?
    
    let buttonOffset = CGFloat(50)
    var aspectFitZoomScale = CGFloat(0)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.delegate = self
        
        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = false
        self.bounces = false
        
        addSubview(mediaView)
        mediaConstraintGroup = constrain(self, mediaView) { view, mediaView in
            mediaView.edges == inset(view.edges, 0, 0, 0, 0)
        }
        
        addSubview(progressView)
        constrain(progressView) { progressView in
            progressView.width == 20
            progressView.height == 20
        }
        progressConstraintGroup = constrain(self, progressView) { view, progressView in
            progressView.top == view.top
            progressView.left == view.left
        }
        
        progressView.addSubview(errorIndicator)
        constrain(errorIndicator, progressView) { errorView, progressView in
            errorView.edges == progressView.edges
        }
        
        let doubleTapper = UITapGestureRecognizer(target: self, action: #selector(ZoomingPhotoView.imageDoubleTapped(_:))).with {
            $0.numberOfTapsRequired = 2
        }
        self.addGestureRecognizer(doubleTapper)
        
        let singleTapper = UITapGestureRecognizer(target: self, action: #selector(ZoomingPhotoView.imageSingleTapped(_:))).with {
            $0.numberOfTapsRequired = 1
        }
        self.addGestureRecognizer(singleTapper)
        
        singleTapper.require(toFail: doubleTapper)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    var photo : UIImage? {
        didSet {
            mediaView.photo = photo
            adjustZoomScale()
        }
    }
    
    var livePhoto: PHLivePhoto? {
        didSet {
            mediaView.livePhoto = livePhoto
            adjustZoomScale()
        }
    }
    
    var video: AVPlayerItem? {
        didSet {
            mediaView.video = video

            addSubview(videoLoadingSpinner)
            constrain(self, videoLoadingSpinner) { view, spinner in
                spinner.width == 70
                spinner.height == 70
                spinner.center == view.center
            }
            
            addSubview(videoPlayButton)
            constrain(self, videoPlayButton) { view, button in
                button.width == 70
                button.height == 70
                button.center == view.center
            }
            
            playerController = PlayerController(player: mediaView.player!).with {
                $0.startPlayButton = videoPlayButton
                $0.loadingSpinner = videoLoadingSpinner as LoadingSpinner
            }
            
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
        mediaView.didBecomeVisible()
    }
    
    func willBecomeHidden() {
        mediaView.willBecomeHidden()
        playerController?.pause(andReset: true)
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
        if let imageSize = mediaView.imageSize {
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
        guard let imageSize = mediaView.imageSize else {
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
                  let imageSize = mediaView.imageSize else {
            return
        }

        let hPadding = padding.hPadding
        let vPadding = padding.vPadding
        let imageWidth = imageSize.width
        let imageHeight = imageSize.height
        
        constrain(self, mediaView, replace: mediaConstraintGroup) { view, mediaView in
            mediaView.edges == inset(view.edges, vPadding, hPadding, vPadding, hPadding)
        }
        
        constrain(self, progressView, replace: progressConstraintGroup) {view, progressView in
            progressView.top == view.top + vPadding + (zoomScale * imageHeight) - 25
            progressView.left == view.left + hPadding + (zoomScale * imageWidth) - 25
        }
    }
    
    // MARK: UITapGestureRecognizer actions
    func imageDoubleTapped(_ recognizer: UITapGestureRecognizer) {
        let touchPoint = recognizer.location(ofTouch: 0, in: mediaView)

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
            self.photoViewDelegate?.viewWasTapped()
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
                self.photoViewDelegate?.viewWasZoomedIn()
            }
        }
        
        adjustImageConstraints(for: zoomScale)
        layoutIfNeeded()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return mediaView;
    }
    
}
