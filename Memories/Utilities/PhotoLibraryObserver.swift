//
//  PhotoLibraryObserver.swift
//  Memories
//
//  Created by Michael Brown on 02/03/2017.
//  Copyright © 2017 Michael Brown. All rights reserved.
//

import Foundation
import Photos
import ReactiveSwift


class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    
    private let observer: Signal<PHChange, Never>.Observer
    private let library: PHPhotoLibrary
    
    let signal: Signal<PHChange, Never>
    
    init(library: PHPhotoLibrary) {
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
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        observer.send(value: changeInstance)
    }
}


