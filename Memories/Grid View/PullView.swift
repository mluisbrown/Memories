import UIKit
import Core
import Cartography

class PullView: UIView {

    let dateFormatter = DateFormatter()
    var label: UILabel!
    var dateString: String = ""
    var willRelease = false {
        didSet {
            configureLabel()
        }
    }
    
    var date : Date? {
        didSet {
            configureLabel()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        dateFormatter.dateFormat = "MMMM dd"

        backgroundColor = Current.colors.systemBackground
        alpha = 0
        clipsToBounds = true
        
        label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = Current.colors.label
        
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
    
    convenience init(frame: CGRect, date: Date?) {
        self.init(frame: frame)
        self.date = date
    }
    
    private func configureLabel() {
        if (date != nil) {
            dateString = dateFormatter.string(from: date!)
            label.text = (willRelease ? NSLocalizedString("RELEASE FOR ", comment: "") : NSLocalizedString("PULL FOR ", comment: "")) + dateString.uppercased()
        }
    }
    
}
