import UIKit
import Cartography
import Core

class GridViewCell: UICollectionViewCell {
    @IBOutlet var imageView: UIImageView?
    @IBOutlet var durationLabel: UILabel?
    let favImageView = UIImageView(image: UIImage(systemName: "heart.fill")).with {
        $0.tintColor = .white
    }
    let cloudImageView = UIImageView(image: UIImage(systemName: "icloud.and.arrow.down")).with {
        $0.tintColor = Current.colors.label
        $0.contentMode = .scaleAspectFit
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

        addSubview(cloudImageView)
        constrain(cloudImageView) {
            $0.width == 32
            $0.height == 32
        }

        constrain(cloudImageView, self) { cloudImageView, superview in
            cloudImageView.centerY == superview.centerY
            cloudImageView.centerX == superview.centerX
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        assetID = nil
        imageView?.image = nil
        cloudImageView.isHidden = false
        durationLabel?.text = ""
        favImageView.isHidden = true
    }

    func update(with model: GridViewCellModel) {
        assetID = model.assetID
        imageView?.image = model.image
        cloudImageView.isHidden = true
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
