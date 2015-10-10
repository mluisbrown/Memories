//
//  Dynamic.swift
//  Memories
//
//  Created by Michael Brown on 14/09/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

class Dynamic<T> {
    typealias Listener = T -> Void
    var listener: Listener?
    var autoListener: Listener?
    
    func bind(listener: Listener?) {
        self.listener = listener
    }
    
    func bindAndFire(listener: Listener?) {
        self.listener = listener
        listener?(value)
    }
    
    var value: T {
        didSet {
            autoListener?(value)
            listener?(value)
        }
    }
    
    init(_ v: T) {
        value = v
    }
    
    init(_ v: T, autoListener: Listener?) {
        self.value = v
        self.autoListener = autoListener
    }
}