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
    
    var subView: PhotoViewType = .photo(photoView: nil) {
        didSet {
            switch subView {
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
            switch subView {
            case .photo(let photoView) where photoView != nil:
                photoView!.image = newValue
            default:
                let imageView = UIImageView(image: newValue)
                subView = PhotoViewType.photo(photoView: imageView)
            }
        }
        get {
            switch subView {
            case .photo(let photo):
                return photo?.image
            case .livePhoto:
                return nil
            }
        }
    }
    
    var livePhoto: PHLivePhoto? {
        set {
            switch subView {
            case .livePhoto(let livePhotoView) where livePhotoView != nil:
                livePhotoView!.livePhoto = newValue
            default:
                let photoView = PHLivePhotoView()
                photoView.livePhoto = newValue
                photoView.contentMode = .scaleAspectFit
                subView = PhotoViewType.livePhoto(livePhotoView: photoView)
            }
        }
        get {
            switch subView {
            case .photo:
                return nil
            case .livePhoto(let livePhoto):
                return livePhoto?.livePhoto
            }
        }
    }
    
    var imageSize: CGSize? {
        get {
            switch subView {
            case .photo(let imageView):
                return imageView?.image?.size
            case .livePhoto(let livewPhotoView):
                return livewPhotoView?.livePhoto?.size
            }
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

        if let size = imageSize, case .livePhoto = subView {
            constrain(subview) { subview in
                subview.width == size.width
                subview.height == size.height
            }
        }
        
        subviews.forEach { $0.removeFromSuperview() }
        setNeedsLayout()
    }
}
