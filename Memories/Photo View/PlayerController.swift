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

#if DEBUG
// Simple description of CMTime, e.g., 2.4s.
extension CMTime : CustomStringConvertible {
    public var description : String {
        return String(format: "%.1fs", self.seconds)
    }
}

// Simple description of CMTimeRange, e.g., [2.4s, 2.8s].
extension CMTimeRange : CustomStringConvertible {
    public var description: String {
        return "[\(self.start), \(self.end)]"
    }
}

// Convert a collection of NSValues into an array of CMTimeRanges.
private extension Collection where Iterator.Element == NSValue {
    var asTimeRanges : [CMTimeRange] {
        return self.map({ value -> CMTimeRange in
            return value.timeRangeValue
        })
    }
}
#endif

class PlayerController: NSObject {
    
    let player: AVPlayer
    let playerItem: AVPlayerItem
    var observing = false
    
    private let observedKeyPaths = [
        #keyPath(PlayerController.playerItem.playbackLikelyToKeepUp),
        #keyPath(PlayerController.playerItem.playbackBufferEmpty),
        #keyPath(PlayerController.playerItem.loadedTimeRanges)
    ]
    
    private var observerContext = 0
    
    weak var startPlayButton: UIButton? {
        didSet {
            startPlayButton?.addTarget(self, action: #selector(startPlay), for: .touchUpInside)
        }
    }
    
    var startPlayButtonVisible: Bool {
        set {
            UIView.animate(withDuration: 0.25) { [weak self] in
                self?.startPlayButton?.alpha = newValue ? 1 : 0
            }
        }
        get {
            return startPlayButton?.alpha == 1
        }
    }

    var timebaseRate: Float? {
        get {
            guard let timebase = playerItem.timebase else {
                return nil
            }
            
            return Float(CMTimebaseGetRate(timebase))
        }
    }

    
    var loadingSpinner: LoadingSpinner?
    
    init(player: AVPlayer) {
        self.player = player
        self.player.actionAtItemEnd = .pause
        self.playerItem = player.currentItem!
        super.init()
    }
    
    deinit {
        removeObservers()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &observerContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
       
#if DEBUG
        if keyPath == #keyPath(PlayerController.playerItem.playbackLikelyToKeepUp) {
            NSLog("isPlaybackLikelyToKeepUp: \(playerItem.isPlaybackLikelyToKeepUp)")
        }
        else if keyPath == #keyPath(PlayerController.playerItem.playbackBufferEmpty) {
            NSLog("isPlaybackBufferEmpty: \(playerItem.isPlaybackBufferEmpty)")
        }
        else if keyPath == #keyPath(PlayerController.playerItem.loadedTimeRanges) {
            NSLog("Time ranges: \(playerItem.loadedTimeRanges.asTimeRanges.description)")
        }
#endif

        if timebaseRate != player.rate {
            loadingSpinner?.show(loading: true)
        }
        else {
            loadingSpinner?.show(loading: false)
        }
    }
    
    func addObservers() {
        for keyPath in observedKeyPaths {
            addObserver(self, forKeyPath: keyPath, options: [.new, .initial], context: &observerContext)
        }
        observing = true
    }
    
    func removeObservers() {
        if observing {
            for keyPath in observedKeyPaths {
                removeObserver(self, forKeyPath: keyPath, context: &observerContext)
            }
            observing = false
        }
    }
    
    func startPlay() {
        startPlayButtonVisible = false
        
        addObservers()
        player.play()
    }
    
    func pause(andReset reset: Bool) {
        player.pause()
        
        if reset {
            removeObservers()
            player.seek(to: kCMTimeZero)
            startPlayButtonVisible = true
        }
    }
}
