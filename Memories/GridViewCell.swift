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
    var thumbnailImage: UIImage? {
        didSet {
            imageView?.image = thumbnailImage
        }
    }
}
