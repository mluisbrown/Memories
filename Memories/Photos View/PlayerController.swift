import Core
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

    @objc let player: AVPlayer
    @objc let playerItem: AVPlayerItem
    var timeObserver: Any?

    private let observedKeyPaths = [
        #keyPath(PlayerController.playerItem.isPlaybackLikelyToKeepUp),
        #keyPath(PlayerController.playerItem.isPlaybackBufferEmpty),
        #keyPath(PlayerController.playerItem.loadedTimeRanges),
        #keyPath(PlayerController.playerItem.status),
        #keyPath(PlayerController.player.rate)
    ]

    private static var observerContext = 0
    private var playAfterScrub = false
    private var scrubEnded = false
    private let itemDuration: TimeInterval
    private let timeFormatter = DateComponentsFormatter()

    private var isSeekInProgress = false
    private var chaseTime = CMTime.zero
    private var playerCurrentItemStatus = AVPlayerItem.Status.unknown

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
        let time = CMTimeMakeWithSeconds(secondsDuration * Float64(slider.value), preferredTimescale: Int32(NSEC_PER_SEC))

        self.scrubEnded = thenPlay
        seekSmoothlyTo(time: time)
    }

    private func seekSmoothlyTo(time newChaseTime: CMTime) {
        if CMTimeCompare(newChaseTime, chaseTime) != 0 {
            chaseTime = newChaseTime

            if !isSeekInProgress {
                tryToSeekToChaseTime()
            }
        }
    }

    private func tryToSeekToChaseTime() {
        switch playerCurrentItemStatus {
        case .readyToPlay:
            actuallySeekToTime()
        case .unknown, .failed:
            break;
        @unknown default:
            break;
        }
    }

    private func actuallySeekToTime() {
        isSeekInProgress = true
        let seekTimeInProgress = chaseTime

        player.seek(to: seekTimeInProgress, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero) { [weak self] _ in
            guard let sself = self else {
                return
            }

            if CMTimeCompare(seekTimeInProgress, sself.chaseTime) == 0 {
                sself.isSeekInProgress = false

                if let slider = sself.slider,
                    slider.value < slider.maximumValue,
                    sself.scrubEnded,
                    sself.playAfterScrub {
                    sself.player.play()
                }
            }
            else {
                sself.tryToSeekToChaseTime()
            }
        }
    }

    // MARK: KVO

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &PlayerController.observerContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }

#if DEBUG
        if keyPath == #keyPath(PlayerController.playerItem.isPlaybackLikelyToKeepUp) {
            NSLog("isPlaybackLikelyToKeepUp: \(playerItem.isPlaybackLikelyToKeepUp)")
        }
        else if keyPath == #keyPath(PlayerController.playerItem.isPlaybackBufferEmpty) {
            NSLog("isPlaybackBufferEmpty: \(playerItem.isPlaybackBufferEmpty)")
        }
        else if keyPath == #keyPath(PlayerController.playerItem.loadedTimeRanges) {
            NSLog("Time ranges: \(playerItem.loadedTimeRanges.asTimeRanges.description)")
        }
        else if keyPath == #keyPath(PlayerController.playerItem.status) {
            NSLog("Player item status: \(playerItem.status.rawValue)")
        }
#endif

        if keyPath == #keyPath(PlayerController.playerItem.status) {
            playerCurrentItemStatus = playerItem.status

            switch playerItem.status {
            case .readyToPlay:
                loadingSpinner?.show(loading: false)
            case .unknown, .failed:
                loadingSpinner?.show(loading: true)
            @unknown default:
                loadingSpinner?.show(loading: true)
            }
        }
        else if keyPath == #keyPath(PlayerController.player.rate) {
            playPauseButton?.isSelected = (player.rate != 0)
        }
    }

    private func addObservers() {
        for keyPath in observedKeyPaths {
            addObserver(self, forKeyPath: keyPath, options: [.new, .initial], context: &PlayerController.observerContext)
        }
    }

    private func addTimeObserver() {
        let frameRate = playerItem.asset.tracks(withMediaType: AVMediaType.video).first?.nominalFrameRate ?? 30
        let frameDuration = 1 / frameRate

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(Float64(frameDuration), preferredTimescale: Int32(NSEC_PER_SEC)), queue: nil) { [weak self] _ in
            self?.playerTimeChanged()
        }
    }

    private func removeObservers() {
        for keyPath in observedKeyPaths {
            removeObserver(self, forKeyPath: keyPath, context: &PlayerController.observerContext)
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
            player.seek(to: CMTime.zero)
            startPlayButtonVisible = true
        }
    }


    // MARK: Actions

    @objc func playPause() {
        startPlayButtonVisible = false

        if player.rate == 0 {
            if CMTimeCompare(player.currentTime(), playerItem.duration) == 0 {
                player.seek(to: CMTime.zero) {_ in
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

    @objc func sliderValueChanged(sender: UISlider, event: UIEvent) {
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
