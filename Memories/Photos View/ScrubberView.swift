//
//  ScrubberView.swift
//  Memories
//
//  Created by Michael Brown on 19/11/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import UIKit
import Cartography

class ScrubberView: UIView {

    let playPauseButton = UIButton(type: .custom).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        $0.setImage(UIImage(named: "play")?.withRenderingMode(.alwaysTemplate), for: .normal)
        $0.setImage(UIImage(named: "pause")?.withRenderingMode(.alwaysTemplate), for: .selected)
        $0.tintColor = .white
    }
    
    let scrubberSlider = UISlider().with {
        $0.setThumbImage(CAShapeLayer.circle(fillColor: .white, diameter: 15).toImage(), for: .normal)
        
        let tileImageFrame = CGRect(origin: .zero, size: CGSize(width: 1, height: 2))
        
        let minTrackLayer = CALayer()
        minTrackLayer.backgroundColor = UIColor.white.cgColor
        minTrackLayer.frame = tileImageFrame
        
        let maxTrackLayer = CALayer()
        maxTrackLayer.backgroundColor = UIColor.darkGray.cgColor
        maxTrackLayer.frame = tileImageFrame
        
        $0.setMinimumTrackImage(minTrackLayer.toImage(), for: .normal)
        $0.setMaximumTrackImage(maxTrackLayer.toImage(), for: .normal)
    }
    
    let currentTimeLabel = UILabel().with {
        $0.font = UIFont.systemFont(ofSize: 12)
        $0.textColor = .white
        $0.text = "0:00"
    }

    let remainingTimeLabel = UILabel().with {
        let x = UILabel()
        $0.font = UIFont.systemFont(ofSize: 12)
        $0.textColor = .white
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
        currentTimeLabel.setContentHuggingPriority(UILayoutPriorityDefaultHigh, for: .horizontal)

        addSubview(remainingTimeLabel)
        constrain(self, remainingTimeLabel) { view, label in
            label.centerY == view.centerY
            label.right == view.right - 5
        }
        remainingTimeLabel.setContentHuggingPriority(UILayoutPriorityDefaultHigh, for: .horizontal)

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
}
