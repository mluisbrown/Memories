import UIKit
import Core
import Cartography

class ScrubberView: UIView {

    let playPauseButton = UIButton(type: .custom).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        $0.setImage(UIImage(named: "play")?.withRenderingMode(.alwaysTemplate), for: .normal)
        $0.setImage(UIImage(named: "pause")?.withRenderingMode(.alwaysTemplate), for: .selected)
        $0.tintColor = Current.colors.label
    }
    
    let scrubberSlider = UISlider().with {
        configureScrubberSlider(slider: $0)
    }
    
    let currentTimeLabel = UILabel().with {
        $0.font = UIFont.systemFont(ofSize: 12)
        $0.textColor = Current.colors.label
        $0.text = "0:00"
    }

    let remainingTimeLabel = UILabel().with {
        let x = UILabel()
        $0.font = UIFont.systemFont(ofSize: 12)
        $0.textColor = Current.colors.label
        $0.text = "0:00"
    }

    init() {
        super.init(frame: .zero)

        addSubview(playPauseButton)
        constrain(self, playPauseButton) { view, button in
            button.width == 40
            button.height == 40
            button.centerY == view.centerY
            button.left == view.left
        }
        
        addSubview(currentTimeLabel)
        constrain(self, currentTimeLabel, playPauseButton) { view, label, button in
            label.centerY == view.centerY
            label.left == button.right
        }
        currentTimeLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .horizontal)

        addSubview(remainingTimeLabel)
        constrain(self, remainingTimeLabel) { view, label in
            label.centerY == view.centerY
            label.right == view.right - 5
        }
        remainingTimeLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .horizontal)

        addSubview(scrubberSlider)
        constrain(self, currentTimeLabel, remainingTimeLabel, scrubberSlider) { view, leftLabel, rightLabel, slider in
            slider.height == 20
            slider.centerY == view.centerY
            slider.left == leftLabel.right + 5
            slider.right == rightLabel.left - 5
        }
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not available")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        Self.configureScrubberSlider(slider: scrubberSlider)
    }

    private static func configureScrubberSlider(slider: UISlider) {
        slider.setThumbImage(CAShapeLayer.circle(fillColor: Current.colors.label, diameter: 15).toImage(), for: .normal)

        let tileImageFrame = CGRect(origin: .zero, size: CGSize(width: 1, height: 2))

        let minTrackLayer = CALayer()
        minTrackLayer.backgroundColor = Current.colors.label.cgColor
        minTrackLayer.frame = tileImageFrame

        let maxTrackLayer = CALayer()
        if #available(iOS 13.0, *) {
            maxTrackLayer.backgroundColor = UIColor.opaqueSeparator.cgColor
        } else {
            maxTrackLayer.backgroundColor = UIColor.darkGray.cgColor
        }
        maxTrackLayer.frame = tileImageFrame

        slider.setMinimumTrackImage(minTrackLayer.toImage(), for: .normal)
        slider.setMaximumTrackImage(maxTrackLayer.toImage(), for: .normal)
    }
}
