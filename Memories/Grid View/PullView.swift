//
//  PullView.swift
//  Memories
//
//  Created by Michael Brown on 17/08/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit
import Cartography

class PullView: UIView {

    let dateFormatter = NSDateFormatter()
    var label: UILabel!
    var dateString: String = ""
    var willRelease = false {
        didSet {
            configureLabel()
        }
    }
    
    var date : NSDate? {
        didSet {
            configureLabel()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        dateFormatter.dateFormat = "MMMM dd"

        backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.08)
        alpha = 0
        clipsToBounds = true
        
        label = UILabel()
        label.font = UIFont.systemFontOfSize(16)
        label.textColor = UIColor.whiteColor()
        
        // center the label in the pull view
        addSubview(label)
        constrain(label) { label in
            label.center == label.superview!.center
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.label = UILabel()
    }
    
    convenience init(frame: CGRect, date: NSDate?) {
        self.init(frame: frame)
        self.date = date
    }
    
    private func configureLabel() {
        if (date != nil) {
            dateString = dateFormatter.stringFromDate(date!)
            label.text = (willRelease ? NSLocalizedString("RELEASE FOR ", comment: "") : NSLocalizedString("PULL FOR ", comment: "")) + dateString.uppercaseString
        }
    }
    
}
