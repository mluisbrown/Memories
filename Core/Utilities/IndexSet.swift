import Foundation

extension IndexSet {
    public func indexPathsFromIndexes(in section : Int) -> [IndexPath] {
        var indexPaths = [IndexPath]()
        
        (self as NSIndexSet).enumerate ({index, stop in
            indexPaths.append(IndexPath(item: index, section: section))
        })
        
        return indexPaths
    }
}
