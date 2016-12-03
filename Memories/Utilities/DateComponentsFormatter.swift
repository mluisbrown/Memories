//
//  DateComponentsFormatter.swift
//  Memories
//
//  Created by Michael Brown on 26/11/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import Foundation

extension DateComponentsFormatter {
    func videoDuration(from duration: TimeInterval) -> String? {
        zeroFormattingBehavior = .pad
        allowedUnits = duration > 3600 ? [.hour, .minute, .second] : [.minute, .second]
        
        return string(from: round(duration))
    }
}
