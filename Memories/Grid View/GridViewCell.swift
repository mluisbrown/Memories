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
    var assetID: String?

    override func prepareForReuse() {
        super.prepareForReuse()
        assetID = nil
        imageView?.image = nil
        durationLabel?.text = ""
    }

    func update(with model: GridViewCellModel) {
        assetID = model.assetID
        imageView?.image = model.image
        durationLabel?.text = model.durationText
    }
}

struct GridViewCellModel {
    let assetID: String?
    let image: UIImage?
    let durationText: String
}
