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
import ReactiveSwift
import Result

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

class ZoomingPhotoView: UIView, UIScrollViewDelegate {

    private let model: PhotoViewModel
    
    var imageRequestId : PHImageRequestID?

    private let scrollView = UIScrollView().with {
        $0.showsHorizontalScrollIndicator = false
        $0.showsVerticalScrollIndicator = false
        $0.bounces = false
    }
    
    private let progressView = DACircularProgressView().with {
        $0.roundedCorners = Int(false)
        $0.thicknessRatio = 1
        $0.trackTintColor = UIColor.clear
        $0.layer.borderColor = UIColor.white.cgColor
        $0.layer.borderWidth = 1
        $0.layer.cornerRadius = 10;
        $0.isHidden = true
    }
    
    private let errorIndicator = UILabel().with {
        $0.text = "!"
        $0.textAlignment = .center
        $0.font = UIFont.boldSystemFont(ofSize: 14)
        $0.textColor = UIColor.white
        $0.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        $0.isHidden = true
    }
    
    private let videoLoadingSpinner = DACircularProgressView().with {
        $0.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        $0.thicknessRatio = 0.1
        $0.indeterminateDuration = 1
        $0.indeterminate = 0
        $0.isHidden = true
        $0.setProgress(0.33, animated: false)
    }
    
    private let videoPlayButton = UIButton.circlePlayButton(diameter: 70).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private let scrubberView = ScrubberView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        $0.layer.cornerRadius = 5
    }
    
    private var accessoryViews: [UIView]?
    
    private var playerController: PlayerController?
    
    private var mediaConstraintGroup: ConstraintGroup?
    private var progressConstraintGroup : ConstraintGroup?
    
    private let buttonOffset = CGFloat(50)
    private var aspectFitZoomScale = CGFloat(0)

    var photoViewDelegate: ZoomingPhotoViewDelegate?
    let mediaView = MediaView().with {
        $0.isUserInteractionEnabled = true
        $0.translatesAutoresizingMaskIntoConstraints = false
    }
    
    init( model: PhotoViewModel) {
        self.model = model
        
        super.init(frame: .zero)

        bindToModel()
        
        accessoryViews = [videoPlayButton, scrubberView, videoLoadingSpinner, progressView, errorIndicator]
        
        scrollView.delegate = self
        
        addSubview(scrollView)
        constrain(self, scrollView) { view, scrollView in
            scrollView.edges == view.edges
        }
        
        scrollView.addSubview(mediaView)
        mediaConstraintGroup = constrain(scrollView, mediaView) { scrollView, mediaView in
            mediaView.edges == inset(scrollView.edges, 0, 0, 0, 0)
        }
        
        scrollView.addSubview(progressView)
        constrain(progressView) { progressView in
            progressView.width == 20
            progressView.height == 20
        }
        progressConstraintGroup = constrain(scrollView, progressView) { scrollView, progressView in
            progressView.top == scrollView.top
            progressView.left == scrollView.left
        }
        
        progressView.addSubview(errorIndicator)
        constrain(errorIndicator, progressView) { errorView, progressView in
            errorView.edges == progressView.edges
        }
        
        let doubleTapper = UITapGestureRecognizer(target: self, action: #selector(ZoomingPhotoView.imageDoubleTapped(_:))).with {
            $0.numberOfTapsRequired = 2
        }
        scrollView.addGestureRecognizer(doubleTapper)
        
        let singleTapper = UITapGestureRecognizer(target: self, action: #selector(ZoomingPhotoView.imageSingleTapped(_:))).with {
            $0.numberOfTapsRequired = 1
        }
        scrollView.addGestureRecognizer(singleTapper)
        
        singleTapper.require(toFail: doubleTapper)
    }

    private func bindToModel() {
        model.assetResource.signal
            .take(during: self.reactive.lifetime)
            .skipNil()
            .on(value: { [weak self] _ in
                self?.model.imageIsPreview.value = false
            })
            .observe(on: QueueScheduler.main)
            .observeValues { [weak self] in
                self?.progressView.isHidden = true

                switch $0 {
                case .photo(let image):
                    self?.mediaView.photo = image
                case .livePhoto(let livePhoto):
                    self?.mediaView.livePhoto = livePhoto
                case .video(let playerItem):
                    self?.mediaView.video = playerItem
                    self?.configureVideoAccessoryViews()
                }
                self?.adjustZoomScale()                
        }
        
        model.previewImage.signal
            .take(during: self.reactive.lifetime)
            .skipNil()
            .on(value: { [weak self] _ in
                self?.model.imageIsPreview.value = true
            })
            .observe(on: QueueScheduler.main)
            .observeValues { [weak self] in
                self?.mediaView.photo = $0
                self?.adjustZoomScale()
        }
        
        model.progress.signal
            .take(during: self.reactive.lifetime)
            .observe(on: QueueScheduler.main)
            .observeValues { [weak self] in
            self?.updateProgress($0)
        }
        
        model.indeterminateProgress.signal
            .take(during: self.reactive.lifetime)
            .observe(on: QueueScheduler.main)
            .observeValues { [weak self] in
            self?.updateProgress(indeterminate: $0)
        }
        
        model.fullImageUnavailable.signal
            .take(during: self.reactive.lifetime)
            .observe(on: QueueScheduler.main)
            .filter { $0 }
            .observeValues { [weak self] _ in
                self?.errorIndicator.isHidden = false
                self?.progressView.isHidden = false
                self?.progressView.setProgress(0.0, animated: false)
        }
    }
    
    private func configureVideoAccessoryViews() {
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
        
        addSubview(scrubberView)
        constrain(self, scrubberView) { view, scrubberView in
            scrubberView.height == 40
            scrubberView.bottom == view.bottom - 10
            scrubberView.left == view.left + buttonOffset + 5
            scrubberView.right == view.right - buttonOffset - 5
        }
        
        playerController = PlayerController(player: mediaView.player!).with {
            $0.startPlayButton = videoPlayButton
            $0.playPauseButton = scrubberView.playPauseButton
            $0.slider = scrubberView.scrubberSlider
            $0.currentTimeLabel = scrubberView.currentTimeLabel
            $0.remainingTimeLabel = scrubberView.remainingTimeLabel
            $0.loadingSpinner = videoLoadingSpinner as LoadingSpinner
        }
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not available")
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
    
    private func updateProgress(_ progress: Double = 0.33, indeterminate: Bool = false) {
        if indeterminate {
            progressView.setProgress(CGFloat(progress), animated: false)
            progressView.isHidden = false
            progressView.indeterminateDuration = 1
            progressView.indeterminate = 1
        }
        else {
            progressView.indeterminate = 0
            progressView.isHidden = progress >= 1.0
            progressView.setProgress(CGFloat(progress), animated: true)
        }
    }
    
    func prepareForDragging() {
        playerController?.pause(andReset: false)
        
        UIView.animate(withDuration: 0.25) {
            self.accessoryViews?.forEach {
                if $0.alpha == 1 { $0.alpha = 0.01 }
            }
        }
    }
    
    func dragWasCancelled() {
        UIView.animate(withDuration: 0.25) {
            self.accessoryViews?.forEach {
                if $0.alpha != 0 { $0.alpha = 1 }
            }
        }
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
            
            scrollView.minimumZoomScale = minZoom
            scrollView.maximumZoomScale = minZoom * 4
            scrollView.zoomScale = minZoom
            
            // only allow scrolling if the image has been zoomed
            // larger than the window
            scrollView.isScrollEnabled = scrollView.zoomScale > minZoom
            
            adjustImageConstraints(for: scrollView.zoomScale)
        }
    }
    
    // MARK: UIView
    
    override func updateConstraints() {
        adjustImageConstraints(for: scrollView.zoomScale)
    
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
        
        constrain(scrollView, mediaView, replace: mediaConstraintGroup) { scrollView, mediaView in
            mediaView.edges == inset(scrollView.edges, vPadding, hPadding, vPadding, hPadding)
        }
        
        constrain(scrollView, progressView, replace: progressConstraintGroup) {scrollView, progressView in
            progressView.top == scrollView.top + vPadding + (zoomScale * imageHeight) - 25
            progressView.left == scrollView.left + hPadding + (zoomScale * imageWidth) - 25
        }
    }
    
    // MARK: UITapGestureRecognizer actions
    func imageDoubleTapped(_ recognizer: UITapGestureRecognizer) {
        let touchPoint = recognizer.location(ofTouch: 0, in: mediaView)

        if scrollView.zoomScale < aspectFitZoomScale {
            zoom(to: aspectFitZoomScale, animated: true)
        }
        else if scrollView.zoomScale == scrollView.minimumZoomScale ||
            scrollView.zoomScale == aspectFitZoomScale {
            zoom(to: scrollView.zoomScale * 3, center: touchPoint, animated: true)
        }
        else {
            zoom(to: scrollView.minimumZoomScale, animated: true)
        }
    }

    func imageSingleTapped(_ recognizer: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.25) {
            self.photoViewDelegate?.viewWasTapped()
            self.scrubberView.alpha = self.scrubberView.alpha == 1 ? 0 : 1
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
            self.scrollView.zoom(to: rect, animated: false)
            self.layoutIfNeeded()
        }
    }
    
    private func zoom(to scale: CGFloat, animated: Bool) {
        adjustImageConstraints(for: scale)
        UIView.animate(withDuration: animated ? 0.5 : 0) {
            self.scrollView.setZoomScale(scale, animated: false)
            self.layoutIfNeeded()
        }
    }
    
    
    // MARK: UIScrollViewDelegate
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        scrollView.isScrollEnabled = scrollView.zoomScale >= scrollView.minimumZoomScale
        
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            UIView.animate(withDuration: 0.25) {
                self.photoViewDelegate?.viewWasZoomedIn()
                self.scrubberView.alpha = 0
            }
        }
        
        adjustImageConstraints(for: scrollView.zoomScale)
        layoutIfNeeded()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return mediaView;
    }
    
}
