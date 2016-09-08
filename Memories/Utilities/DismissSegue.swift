//
//  DismissSegue.swift
//  Memories
//
//  Created by Michael Brown on 29/07/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit

class DismissSegue: UIStoryboardSegue {
    override func perform() {
        let sourceVC = source;
        sourceVC.presentingViewController?.dismiss(animated: true, completion: nil);	
    }
    
}
