//
//  StatusBarViewController.swift
//  Memories
//
//  Created by Michael Brown on 25/07/2016.
//  Copyright © 2016 Michael Brown. All rights reserved.
//

import UIKit

protocol StatusBarViewController {
    func hideStatusBar(hide: Bool)
}

extension UIViewController {
    
    func statusBarContoller() -> StatusBarViewController? {
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