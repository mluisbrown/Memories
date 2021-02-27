import UIKit
import AVFoundation
import Core
import Cartography

class VideoView: UIView {

    private static var observerContext = 0
    
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
        player?.removeObserver(self, forKeyPath: "status")
    }

    var playerItem: AVPlayerItem? {
        set {
            self.player = AVPlayer().with {
                $0.usesExternalPlaybackWhileExternalScreenIsActive = true
                $0.allowsExternalPlayback = true
            }

            if let videoLayer = self.layer as? AVPlayerLayer {
                videoLayer.player = player
                videoLayer.videoGravity = AVLayerVideoGravity.resizeAspect
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
            player?.removeObserver(self, forKeyPath: "status", context: &VideoView.observerContext)
        }
        didSet {
            player?.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: &VideoView.observerContext)
        }
    }
    
    init() {
        super.init(frame: .zero)

        addSubview(previewImageView)
        constrain(self, previewImageView) {view, imageView in
            view.edges == imageView.edges
        }
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not available")
    }
    
    override class var layerClass : AnyClass {
        return AVPlayerLayer.self
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &VideoView.observerContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }

        if let status = player?.status,
            status == .readyToPlay {
            previewImageVisible = false
        }
    }
    
}
