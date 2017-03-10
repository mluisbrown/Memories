//
//  GridViewCell.swift
//  Memories
//
//  Created by Michael Brown on 18/06/2015.
//  Copyright (c) 2015 Michael Brown. All rights reserved.
//

import UIKit

class GridViewCell: UICollectionViewCell {
    @IBOutlet var imageView: UIImageView?
    @IBOutlet var durationLabel: UILabel?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView?.image = nil
        durationLabel?.text = ""
    }
}
