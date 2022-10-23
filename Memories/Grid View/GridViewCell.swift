import UIKit
import Cartography
import Core

class GridViewCell: UICollectionViewCell {
    @IBOutlet var imageView: UIImageView?
    @IBOutlet var durationLabel: UILabel?
    let favImageView = UIImageView(image: UIImage(systemName: "heart.fill")).with {
        $0.tintColor = .white
    }
    var assetID: String?

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        addSubview(favImageView)
        constrain(favImageView) {
            $0.height == 12
            $0.width == 12
        }

        constrain(favImageView, self) { favImageView, superview in
            favImageView.leading == superview.leading + 4
            favImageView.bottom == superview.bottom - 4
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        assetID = nil
        imageView?.image = nil
        durationLabel?.text = ""
        favImageView.isHidden = true
    }

    func update(with model: GridViewCellModel) {
        assetID = model.assetID
        imageView?.image = model.image
        durationLabel?.text = model.durationText
        favImageView.isHidden = model.isFavourite == false
    }
}

struct GridViewCellModel {
    let assetID: String?
    let image: UIImage?
    let durationText: String
    let isFavourite: Bool
}
