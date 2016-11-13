//
//  PlayerController.swift
//  Memories
//
//  Created by Michael Brown on 11/11/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import UIKit
import AVFoundation

protocol LoadingSpinner {
    func show(loading: Bool)
}


class PlayerController: NSObject {
    
    let player: AVPlayer
    let playerItem: AVPlayerItem
    var observing = false
    
    weak var startPlayButton: UIButton? {
        didSet {
            startPlayButton?.addTarget(self, action: #selector(startPlay), for: .touchUpInside)
        }
    }
    
    var loadingSpinner: LoadingSpinner?
    
    init(player: AVPlayer) {
        self.player = player
        self.playerItem = player.currentItem!
        super.init()
    }
    
    deinit {
        removePlaybackObserver()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        NSLog("PC: isPlaybackLikelyToKeepUp: \(playerItem.isPlaybackLikelyToKeepUp), isPlaybackBufferEmpty: \(playerItem.isPlaybackBufferEmpty)")
        
        if !playerItem.isPlaybackLikelyToKeepUp {
            if playerItem.isPlaybackBufferEmpty {
                loadingSpinner?.show(loading: true)
            }
        }
        else {
            loadingSpinner?.show(loading: false)
        }
    }
    
    func addPlaybackObserver() {
        playerItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
        observing = true
    }
    
    func removePlaybackObserver() {
        if observing {
            self.playerItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
            self.playerItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            observing = false
        }
    }
    
    func startPlay() {
        NSLog("PC: startPlay()")
        NSLog("PC: isPlaybackLikelyToKeepUp: \(playerItem.isPlaybackLikelyToKeepUp), isPlaybackBufferEmpty: \(playerItem.isPlaybackBufferEmpty)")

        setStartPlayButton(visible: false)
        
        if !playerItem.isPlaybackLikelyToKeepUp {
            loadingSpinner?.show(loading: true)
        }
        
        player.play()
        addPlaybackObserver()
    }
    
    func pause(andReset reset: Bool) {
        NSLog("PC: pause(andReset: \(reset))")
        player.pause()
        
        if reset {
            removePlaybackObserver()
            player.seek(to: kCMTimeZero)
            setStartPlayButton(visible: true)
        }
    }
    
    func setStartPlayButton(visible: Bool) {
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.startPlayButton?.alpha = visible ? 1 : 0
        }
    }
}
