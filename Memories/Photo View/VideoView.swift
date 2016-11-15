//
//  VideoView.swift
//  Memories
//
//  Created by Michael Brown on 04/11/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import UIKit
import AVFoundation
import Cartography

class VideoView: UIView {

    private let observedKeyPaths = [
        #keyPath(VideoView.player.status),
        #keyPath(VideoView.player.rate)
    ]
    private var observerContext = 0
    
    let previewImageView = UIImageView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }
    
    var previewImageVisible: Bool {
        set {
            UIView.animate(withDuration: 0.3) { [weak self] in
                self?.previewImageView.alpha = newValue ? 1 : 0
            }
        }
        get {
            return previewImageView.alpha == 1
        }
    }
    
    var image: UIImage? {
        didSet {
            previewImageView.image = image
        }
    }
    
    deinit {
        for keyPath in observedKeyPaths {
            removeObserver(self, forKeyPath: keyPath, context: nil)
        }
    }

    var playerItem: AVPlayerItem? {
        set {
            self.player = AVPlayer()

            if let videoLayer = self.layer as? AVPlayerLayer {
                videoLayer.player = player
                videoLayer.videoGravity = AVLayerVideoGravityResizeAspect
            }
            // only set item once AVPlayerLayer has been setup
            // optimization recommended in Session 503 from WWDC 2016 (https://developer.apple.com/videos/play/wwdc2016/503/)
            self.player?.replaceCurrentItem(with: newValue)
        }
        get {
            return self.player?.currentItem
        }
    }
    
    var player: AVPlayer? {
        willSet {
            for keyPath in observedKeyPaths {
                removeObserver(self, forKeyPath: keyPath, context: &observerContext)
            }
        }
        didSet {
            for keyPath in observedKeyPaths {
                addObserver(self, forKeyPath: keyPath, options: [.new, .initial], context: &observerContext)
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(previewImageView)
        constrain(self, previewImageView) {view, imageView in
            view.edges == imageView.edges
        }
    }

    convenience init() {
        self.init(frame: .zero)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override class var layerClass : AnyClass {
        return AVPlayerLayer.self
    }

    func reset() {
        previewImageVisible = true
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let status = player?.status,
            let rate = player?.rate,
            status == .readyToPlay,
            rate != 0 {
            previewImageVisible = false
        }
    }
    
}
