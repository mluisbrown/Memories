//
//  IndexSet.swift
//  Memories
//
//  Created by Michael Brown on 23/01/2017.
//  Copyright © 2017 Michael Brown. All rights reserved.
//

import Foundation

extension IndexSet {
    func indexPathsFromIndexes(in section : Int) -> [IndexPath] {
        var indexPaths = [IndexPath]()
        
        (self as NSIndexSet).enumerate ({index, stop in
            indexPaths.append(IndexPath(item: index, section: section))
        })
        
        return indexPaths
    }
}
