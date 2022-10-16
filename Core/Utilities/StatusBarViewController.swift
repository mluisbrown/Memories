import UIKit

public protocol StatusBarViewController {
    func hideStatusBar(_ hide: Bool)
}

extension UIViewController {
    public func statusBarContoller() -> StatusBarViewController? {
        let vcStatusBar : StatusBarViewController?
        if let navController = self as? UINavigationController {
            vcStatusBar = navController.topViewController as? StatusBarViewController
        }
        else {
            vcStatusBar = self as? StatusBarViewController
        }
        
        return vcStatusBar
    }
}
