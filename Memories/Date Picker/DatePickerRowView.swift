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

    let dateLabel = UILabel().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            $0.textColor = UIColor.label
        } else {
            $0.textColor = UIColor.white
        }
    }
    let countLabel = UILabel().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            $0.textColor = UIColor.label
        } else {
            $0.textColor = UIColor.white
        }
    }
    let dateFormatter = DateFormatter().with {
        $0.dateFormat = "MMMM dd"
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(dateLabel)
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
        super.init(frame: CGRect.zero)
    }
    
    func setData(date: Date, count: Int) {
        dateLabel.text = dateFormatter.string(from: date).uppercased()
        countLabel.text = "\(count)"
    }
}
