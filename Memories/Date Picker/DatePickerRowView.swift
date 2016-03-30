//
//  DatePickerRowView.swift
//  Memories
//
//  Created by Michael Brown on 25/11/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit
import Cartography

class DatePickerRowView: UIView {

    let dateLabel = UILabel()
    let countLabel = UILabel()
    let dateFormatter = NSDateFormatter()
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        dateFormatter.dateFormat = "MMMM dd"
        
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.textColor = UIColor.whiteColor()
        addSubview(dateLabel)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.textColor = UIColor.whiteColor()
        addSubview(countLabel)
        
        constrain(self, dateLabel) {view, dateLabel in
            dateLabel.left == view.left + 16
            dateLabel.top == view.top
            dateLabel.bottom == view.bottom
        }

        constrain(self, countLabel) {view, countLabel in
            countLabel.right == view.right - 16
            countLabel.top == view.top
            countLabel.bottom == view.bottom
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(frame: CGRectZero)
    }
    
    func setData(date: NSDate, count: Int) {
        dateLabel.text = dateFormatter.stringFromDate(date).uppercaseString
        countLabel.text = "\(count)"
    }
}
