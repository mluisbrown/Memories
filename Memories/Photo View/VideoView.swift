//
//  VideoView.swift
//  Memories
//
//  Created by Michael Brown on 04/11/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import UIKit
import AVFoundation

class VideoView: UIView {

    var playerItem: AVPlayerItem? {
        didSet {
            if let playerItem = playerItem {
                player = AVPlayer(playerItem: playerItem)
                playerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
            }
        }
        
        willSet {
            playerItem?.removeObserver(self, forKeyPath: "status")
        }
    }
    
    deinit {
        playerItem?.removeObserver(self, forKeyPath: "status")
    }
    
    var player: AVPlayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
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
    
    func play() {
        player?.play()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let status = playerItem?.status {
            if status == .readyToPlay {
                if let videoLayer = self.layer as? AVPlayerLayer {
                    videoLayer.player = player
                    videoLayer.videoGravity = AVLayerVideoGravityResizeAspect
                    player?.play()
                }
            }
        }
    }
    
}
