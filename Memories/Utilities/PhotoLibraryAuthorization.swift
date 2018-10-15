//
//  PhotoLibraryAuthorization.swift
//  Memories
//
//  Created by Michael Brown on 10/03/2017.
//  Copyright © 2017 Michael Brown. All rights reserved.
//

import Foundation
import UIKit
import Photos
import ReactiveSwift
import Result

struct PhotoLibraryAuthorization {
    static func checkPhotosPermission() -> SignalProducer<PHAuthorizationStatus, NoError> {
        let authStatus = PHPhotoLibrary.authorizationStatus();
        
        return SignalProducer<PHAuthorizationStatus, NoError> { observer, _ in
            observer.send(value: authStatus)
            
            var alert: UIAlertController?
            
            switch authStatus {
            case .authorized:
                observer.sendCompleted()
            case .notDetermined:
                alert = UIAlertController(title: NSLocalizedString("Let Memories access Photos?", comment: ""), message: NSLocalizedString("Memories can only work if it has access to your photos. If you tap 'Allow' iOS will ask your permission.", comment: ""), preferredStyle: .alert)
                let allow = UIAlertAction(title: NSLocalizedString("Allow", comment: ""), style: .default) { _ in
                    PHPhotoLibrary.requestAuthorization { status in
                        observer.send(value: status)
                        observer.sendCompleted()
                    }
                }
                let deny = UIAlertAction(title: NSLocalizedString("Not Now", comment: ""), style: .cancel) { _ in  observer.sendCompleted() }
                alert?.addAction(deny)
                alert?.addAction(allow)
            case .denied:
                alert = UIAlertController(title: NSLocalizedString("No Access to Photos", comment: ""), message: NSLocalizedString("You have Denied access to Photos for Memories. In order for Memories to work you must enable this access in Settings. Would you like to do this now?", comment: ""), preferredStyle: .alert)
                let settings = UIAlertAction(title: NSLocalizedString("Settings", comment: ""), style: .default) { _ in
                    let url = URL(string: UIApplication.openSettingsURLString)!
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    observer.sendCompleted()
                }
                let nothanks = UIAlertAction(title: NSLocalizedString("No thanks", comment: ""), style: .cancel)  { _ in  observer.sendCompleted() }
                alert?.addAction(nothanks)
                alert?.addAction(settings)
            case .restricted:
                alert = UIAlertController(title: NSLocalizedString("No Access to Photos", comment: ""), message: NSLocalizedString("Access to Photos has been restricted on this device. Unfortunately this means Memories will not work until this is changed.", comment: ""), preferredStyle: .alert)
                let ok = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default)  { _ in  observer.sendCompleted() }
                alert?.addAction(ok)
            }
            
            if let alert = alert {
                UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true)
            }
        }
    }
}
