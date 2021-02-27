import UIKit

public class DismissSegue: UIStoryboardSegue {
    public override func perform() {
        let sourceVC = source;
        sourceVC.presentingViewController?.dismiss(animated: true, completion: nil);	
    }
}
