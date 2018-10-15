//
//  PhotoView.swift
//  Memories
//
//  Created by Michael Brown on 02/11/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import UIKit
import PhotosUI
import Cartography
import AVFoundation

class MediaView: UIView {

    enum MediaViewType {
        case photo(photoView: UIImageView?)
        case livePhoto(livePhotoView: PHLivePhotoView?)
        case video(videoView: VideoView?)
    }
    
    var contentView: MediaViewType = .photo(photoView: nil) {
        didSet {
            switch contentView {
            case .photo(let photoView):
                setSubview(photoView)
            case .livePhoto(let livePhotoView):
                setSubview(livePhotoView)
            case .video(let videoView):
                setSubview(videoView)
            }
        }
    }
    
    init() {
        super.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not available")
    }

    override class var layerClass : AnyClass {
        return AVPlayerLayer.self
    }
    
    var photo: UIImage? {
        set {
            switch contentView {
            case .photo(let photoView) where photoView != nil:
                photoView!.image = newValue
            case .photo, .livePhoto, .video:
                let imageView = UIImageView(image: newValue)
                contentView = .photo(photoView: imageView)
            }
        }
        get {
            switch contentView {
            case .photo(let photo):
                return photo?.image
            case .livePhoto, .video:
                return nil
            }
        }
    }
    
    var livePhoto: PHLivePhoto? {
        set {
            switch contentView {
            case .livePhoto(let livePhotoView) where livePhotoView != nil:
                livePhotoView!.livePhoto = newValue
            case .livePhoto, .photo, .video:
                let photoView = PHLivePhotoView()
                photoView.livePhoto = newValue
                photoView.contentMode = .scaleAspectFit
                contentView = .livePhoto(livePhotoView: photoView)
            }
        }
        get {
            switch contentView {
            case .livePhoto(let livePhoto):
                return livePhoto?.livePhoto
            case .photo, .video:
                return nil
            }
        }
    }
    
    var video: AVPlayerItem? {
        set {
            switch contentView {
            case .video(let videoView) where videoView != nil:
                videoView?.playerItem = newValue
            case .video, .livePhoto, .photo:
                let videoView = VideoView()
                videoView.playerItem = newValue
                if case .photo(let imageView) = contentView {
                    videoView.image = imageView?.image
                }
                contentView = .video(videoView: videoView)
            }
        }
        get {
            switch contentView {
            case .video(let videoView):
                return videoView?.playerItem
            case .livePhoto, .photo:
                return nil
            }
        }
    }
    
    var player: AVPlayer? {
        get {
            switch contentView {
            case .video(let videoView):
                return videoView?.player
            case .livePhoto, .photo:
                return nil
            }
        }
    }
    
    var imageSize: CGSize? {
        get {
            switch contentView {
            case .photo(let imageView):
                return imageView?.image?.size
            case .livePhoto(let livewPhotoView):
                return livewPhotoView?.livePhoto?.size
            case .video(let videoView):
                let size = videoView?.playerItem?.asset.tracks(withMediaType: AVMediaType.video).first?.naturalSize
                if let transform = videoView?.playerItem?.asset.tracks(withMediaType: AVMediaType.video).first?.preferredTransform,
                    let naturalSize = size,
                    transform != .identity {
                    return CGSize(width: naturalSize.height, height: naturalSize.width)
                }
                else {
                    return size
                }
            }
        }
    }
    
    func didBecomeVisible() {
        switch contentView {
        case .livePhoto(let livePhotoView):
            livePhotoView?.startPlayback(with: .hint)
        case .photo, .video:
            break
        }
    }
    
    func willBecomeHidden() {
        switch contentView {
        case .livePhoto(let livePhotoView):
            livePhotoView?.stopPlayback()
        case .photo, .video:
            break
        }
    }
    
    private func setSubview(_ view: UIView?) {
        guard let subview = view else {
            return
        }
        
        let subviews = self.subviews
        
        subview.isUserInteractionEnabled = true
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
        bringSubviewToFront(subview)
        
        constrain(self, subview) {view, subview in
            view.edges == subview.edges
        }

        // Unlike UIImageView, PHLivePhotoView does not implement intrinsicContentSize()
        // so we have to add width and height constraints too
        if let size = imageSize {
            switch contentView {
            case .livePhoto, .video:
                constrain(subview) { subview in
                    subview.width == size.width
                    subview.height == size.height
                }
            case .photo:
                break
            }
        }
        
        subviews.forEach { $0.removeFromSuperview() }
        setNeedsLayout()
    }
}
