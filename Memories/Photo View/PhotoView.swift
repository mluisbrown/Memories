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

class PhotoView: UIView {

    enum PhotoViewType {
        case photo(photoView: UIImageView?)
        case livePhoto(livePhotoView: PHLivePhotoView?)
    }
    
    var contentView: PhotoViewType = .photo(photoView: nil) {
        didSet {
            switch contentView {
            case .photo(let photoView):
                setSubview(photoView)
            case .livePhoto(let livePhotoView):
                setSubview(livePhotoView)
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(frame: CGRect.zero)
    }

    var photo: UIImage? {
        set {
            switch contentView {
            case .photo(let photoView) where photoView != nil:
                photoView!.image = newValue
            default:
                let imageView = UIImageView(image: newValue)
                contentView = PhotoViewType.photo(photoView: imageView)
            }
        }
        get {
            switch contentView {
            case .photo(let photo):
                return photo?.image
            case .livePhoto:
                return nil
            }
        }
    }
    
    var livePhoto: PHLivePhoto? {
        set {
            switch contentView {
            case .livePhoto(let livePhotoView) where livePhotoView != nil:
                livePhotoView!.livePhoto = newValue
            default:
                let photoView = PHLivePhotoView()
                photoView.livePhoto = newValue
                photoView.contentMode = .scaleAspectFit
                contentView = PhotoViewType.livePhoto(livePhotoView: photoView)
            }
        }
        get {
            switch contentView {
            case .photo:
                return nil
            case .livePhoto(let livePhoto):
                return livePhoto?.livePhoto
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
            }
        }
    }
    
    func didBecomeVisible() {
        switch contentView {
        case .livePhoto(let livePhotoView) where livePhotoView != nil:
            livePhotoView?.startPlayback(with: .hint)
        default:
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
        bringSubview(toFront: subview)
        
        constrain(self, subview) {view, subview in
            view.top == subview.top
            view.bottom == subview.bottom
            view.left == subview.left
            view.right == subview.right
        }

        // Unlike UIImageView, PHLivePhotoView does not implement intrinsicContentSize()
        // so we have to add width and height constraints too
        if let size = imageSize, case .livePhoto = contentView {
            constrain(subview) { subview in
                subview.width == size.width
                subview.height == size.height
            }
        }
        
        subviews.forEach { $0.removeFromSuperview() }
        setNeedsLayout()
    }
}
