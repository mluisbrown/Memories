import Foundation
import UIKit
import Photos
import ReactiveSwift

public struct PhotoLibraryAuthorization {
    public static func checkPhotosPermission() -> SignalProducer<PHAuthorizationStatus, Never> {
        let authStatus = PHPhotoLibrary.authorizationStatus();
        
        return SignalProducer<PHAuthorizationStatus, Never> { observer, _ in
            observer.send(value: authStatus)
            
            var alert: UIAlertController?
            
            switch authStatus {
            case .authorized,
                 .limited:
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
            @unknown default:
                alert = UIAlertController(title: NSLocalizedString("No Access to Photos", comment: ""), message: NSLocalizedString("Access to Photos has been restricted on this device. Unfortunately this means Memories will not work until this is changed.", comment: ""), preferredStyle: .alert)
                let ok = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default)  { _ in  observer.sendCompleted() }
                alert?.addAction(ok)
            }
            
            if let alert = alert {
                UIApplication.shared.windows.filter(\.isKeyWindow).first?.rootViewController?.present(alert, animated: true)
            }
        }
    }
}
