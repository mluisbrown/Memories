import Foundation
import Photos
import ReactiveSwift

public class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    private let observer: Signal<PHChange, Never>.Observer
    private let library: PHPhotoLibrary
    
    public let signal: Signal<PHChange, Never>
    
    public init(library: PHPhotoLibrary) {
        (signal, observer) = Signal<PHChange, Never>.pipe()
        self.library = library
        super.init()

        self.library.register(self)
    }
    
    deinit {
        observer.sendCompleted()
        library.unregisterChangeObserver(self)
    }
    
    // MARK: - PHPhotoLibraryChangeObserver
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        observer.send(value: changeInstance)
    }
}
