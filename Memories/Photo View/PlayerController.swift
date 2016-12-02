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
    var timeObserver: Any?
    
    private let observedKeyPaths = [
        #keyPath(PlayerController.playerItem.playbackLikelyToKeepUp),
        #keyPath(PlayerController.playerItem.playbackBufferEmpty),
        #keyPath(PlayerController.playerItem.loadedTimeRanges),
        #keyPath(PlayerController.playerItem.status),
        #keyPath(PlayerController.player.rate)
    ]
    
    private var observerContext = 0
    private var playAfterScrub = false
    private let frameDuration: Float
    private let itemDuration: TimeInterval
    private let timeFormatter = DateComponentsFormatter()

    private var isSeekInProgress = false
    private var chaseTime = kCMTimeZero
    private var playerCurrentItemStatus = AVPlayerItemStatus.unknown
    
    weak var startPlayButton: UIButton? {
        didSet {
            startPlayButton?.addTarget(self, action: #selector(playPause), for: .touchUpInside)
        }
    }
    
    var loadingSpinner: LoadingSpinner?
    weak var playPauseButton: UIButton? {
        didSet {
            playPauseButton?.addTarget(self, action: #selector(playPause), for: .touchUpInside)
        }
    }
    weak var slider: UISlider? {
        didSet {
            slider?.addTarget(self, action: #selector(sliderValueChanged(sender:event:)), for: .valueChanged)
        }
    }
    
    weak var currentTimeLabel: UILabel?
    weak var remainingTimeLabel: UILabel?
    
    var startPlayButtonVisible: Bool {
        set {
            guard startPlayButton?.alpha != (newValue ? 1 : 0) else {
                return
            }
            
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

    
    
    init(player: AVPlayer) {
        self.player = player
        self.player.actionAtItemEnd = .pause
        self.playerItem = player.currentItem!
        self.itemDuration = CMTimeGetSeconds(playerItem.asset.duration)
        
        let frameRate = player.currentItem?.asset.tracks(withMediaType: AVMediaTypeVideo).first?.nominalFrameRate ?? 0
        self.frameDuration = 1 / frameRate
        super.init()

        addTimeObserver()
        addObservers()
    }
    
    deinit {
        removeTimeObserver()
        removeObservers()
    }
    
    // MARK: Implementation
    
    private func updatePlayer(thenPlay: Bool) {
        guard let slider = slider else {
            return
        }
        
        let secondsDuration = CMTimeGetSeconds(playerItem.duration)
        let time = CMTimeMakeWithSeconds(secondsDuration * Float64(slider.value), Int32(NSEC_PER_SEC))
        
        player.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero) { [weak self] _ in
            guard let `self` = self else {
                return
            }
            
            if thenPlay && slider.value < slider.maximumValue && self.playAfterScrub {
                self.player.play()
            }
        }
    }
    
    // MARK: KVO
    
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
        else if keyPath == #keyPath(PlayerController.player.rate) {
            NSLog("Player rate: \(player.rate), Timebase rate: \(timebaseRate)")
        }
#endif

        if keyPath == #keyPath(PlayerController.playerItem.status) {
            playerCurrentItemStatus = playerItem.status
        }
        else if keyPath == #keyPath(PlayerController.player.rate) {
            playPauseButton?.isSelected = (player.rate != 0)
        }
        
        if timebaseRate != player.rate && player.rate == 1.0 {
            loadingSpinner?.show(loading: true)
        }
        else {
            loadingSpinner?.show(loading: false)
        }
    }
    
    private func addObservers() {
        for keyPath in observedKeyPaths {
            addObserver(self, forKeyPath: keyPath, options: [.new, .initial], context: &observerContext)
        }
    }
    
    private func addTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(Float64(frameDuration), Int32(NSEC_PER_SEC)), queue: nil) { [weak self] _ in
            guard let `self` = self else {
                return
            }
            
            self.playerTimeChanged()
        }
    }
    
    private func removeObservers() {
        for keyPath in observedKeyPaths {
            removeObserver(self, forKeyPath: keyPath, context: &observerContext)
        }
    }
    
    private func removeTimeObserver() {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }
    
    private func playerTimeChanged() {
        let secondsElapsed = CMTimeGetSeconds(playerItem.currentTime())
        let ratio = itemDuration == 0 ? 0 : secondsElapsed / itemDuration

        currentTimeLabel?.text = timeFormatter.videoDuration(from: secondsElapsed)
        remainingTimeLabel?.text = timeFormatter.videoDuration(from: itemDuration - secondsElapsed)
        
        slider?.value = Float(ratio)
    }
    
    // MARK: API
    
    func pause(andReset reset: Bool) {
        player.pause()
        
        if reset {
            player.seek(to: kCMTimeZero)
            startPlayButtonVisible = true
        }
    }

    
    // MARK: Actions
    
    func playPause() {
        startPlayButtonVisible = false
        
        if player.rate == 0 {
            if CMTimeCompare(player.currentTime(), playerItem.duration) == 0 {
                player.seek(to: kCMTimeZero) {_ in 
                    self.player.play()
                }
            }
            else {
                player.play()
            }
        }
        else {
            player.pause()
        }
    }
    
    func sliderValueChanged(sender: UISlider, event: UIEvent) {
        startPlayButtonVisible = false
        
        if let touch = event.allTouches?.first {
            if touch.phase == .began {
                playAfterScrub = player.rate > 0
                player.pause()
            }

            updatePlayer(thenPlay: touch.phase == .ended)
        }
    }
}
