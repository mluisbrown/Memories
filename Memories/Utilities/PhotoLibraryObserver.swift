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
import Result


class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    
    private let changesPipe = Signal<PHChange, NoError>.pipe()
    private let library: PHPhotoLibrary
    
    let signal: Signal<PHChange, NoError>
    
    init(library: PHPhotoLibrary) {
        self.signal = changesPipe.output
        self.library = library
        super.init()

        self.library.register(self)
    }
    
    deinit {
        changesPipe.input.sendCompleted()
        library.unregisterChangeObserver(self)
    }
    
    // MARK: - PHPhotoLibraryChangeObserver
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        changesPipe.input.send(value: changeInstance)
    }
}


