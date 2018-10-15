//
//  UpgradeManager.swift
//  Memories
//
//  Created by Michael Brown on 30/09/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import UIKit
import Security
import SwiftyStoreKit
import StoreKit

class UpgradeManager {
    static let upgradeProductId = "com.luacheia.memories.Upgrade"
    
    struct Key {
        static let highQualityViewCount = "HighQualityViewCount"
        static let viewCountDate = "ViewCountDate"
        static let upgradePromptShown = "UpgradePromptShown"
        static let appLaunchCountMod3 = "AppLaunchCountMod3"
    }
    
    static let MaxHighQualityViewCount = 5
    
    static private let userDefaults = UserDefaults.standard
    
    static private let priceFormatter = NumberFormatter().with {
        $0.formatterBehavior = .behavior10_4
        $0.numberStyle = .currency
    }
    
    /// flag to indicate if the user been shown the upgrade prompt since starting the app
    static private var upgradePromptShown : Bool {
        get {
            return userDefaults.bool(forKey: Key.upgradePromptShown)
        }
        
        set {
            userDefaults.set(newValue, forKey: Key.upgradePromptShown)
            userDefaults.synchronize()
        }
    }

    /// the localized upgrade price
    static var upgradePrice : String?
    
    /// flag to indicate if the user upgraded the app
    static var upgraded : Bool = {
        return StoreKitPersistence.isPurchased(identifier: upgradeProductId)
        }() {
        
        didSet {
            if upgraded {
                userDefaults.removeObject(forKey: Key.viewCountDate)
                userDefaults.removeObject(forKey: Key.highQualityViewCount)
                userDefaults.synchronize()
                
                StoreKitPersistence.persistPurchase(of: upgradeProductId)
            }
        }
    }
    
    /// count of the number of high quality images the user has seen today
    static var highQualityViewCount : Int {
        get {
            guard !upgraded else {
                return 0
            }
        
            var count = 0
            let today = Date()
        
            if let date = userDefaults.object(forKey: Key.viewCountDate) as? Date {
                let day = Calendar.current.ordinality(of: .day, in: .era, for: date)
                let now = Calendar.current.ordinality(of: .day, in: .era, for: today)
        
                if day != now {
                    userDefaults.set(today, forKey: Key.viewCountDate)
                    userDefaults.set(0, forKey: Key.highQualityViewCount)
                    userDefaults.set(false, forKey: Key.upgradePromptShown)
                } else {
                    count = userDefaults.integer(forKey: Key.highQualityViewCount)
                }
            } else {
                userDefaults.set(today, forKey: Key.viewCountDate)
                userDefaults.set(0, forKey: Key.highQualityViewCount)
                userDefaults.set(false, forKey: Key.upgradePromptShown)
            }
            
            userDefaults.synchronize()
            return count
        }
        
        set {
            guard !upgraded else {
                return
            }
            
            userDefaults.set(newValue, forKey: Key.highQualityViewCount)
            userDefaults.synchronize()
        }
    }

    static func getUpgradePrice(thenCall completion: ((String?) -> ())?) {
        if let price = upgradePrice {
            completion?(price)
            return
        }
        
        SwiftyStoreKit.retrieveProductsInfo([upgradeProductId]) { result in
            if let product = result.retrievedProducts.first {
                priceFormatter.locale = product.priceLocale
                upgradePrice = priceFormatter.string(from: product.price)!
                completion?(upgradePrice)
            }
            else  {
                NSLog("Unabled to obtain upgrade price. Error: \(result.error?.localizedDescription ?? "Error description not available.")")
                completion?(nil)
            }
        }
    }
    
    /// returns whether the user is allowed to view another high quality image
    static func highQualityViewAllowed() -> Bool {
        if !upgraded { getUpgradePrice(thenCall: nil) }
        return upgraded || highQualityViewCount < MaxHighQualityViewCount
    }
    
    /// prompts the user if they want to upgrade
    static func promptForUpgrade(in viewController: UIViewController, completion: ((Bool) -> ())?) {
        guard let price = upgradePrice , !upgradePromptShown else {
            completion?(false)
            return
        }
        
        upgradePromptShown = true
        
        let upgradeTitle : String
        upgradeTitle = NSLocalizedString("Upgrade for ", comment: "") + price
        
        let alert = UIAlertController(title: NSLocalizedString("Five a Day Limit", comment: "")
            , message: NSLocalizedString("You can view 5 full quality photos, live photos or videos per day which you can share, favorite or delete. You can Upgrade to remove this restriction. The Upgrade option is also available in the settings page.", comment: "")
            , preferredStyle: .alert)
        let upgrade = UIAlertAction(title: upgradeTitle, style: .default, handler: { (action) -> Void in
            UpgradeManager.upgrade(thenCall: completion)
        })
        let restore = UIAlertAction(title: NSLocalizedString("Restore", comment: ""), style: .default, handler: { (action) -> Void in
            UpgradeManager.restore(thenCall: completion)
        })
        let notNow = UIAlertAction(title: NSLocalizedString("Not Now", comment: ""), style: .cancel, handler: { (action) -> Void in
            completion?(false)
        })
        alert.addAction(upgrade)
        alert.addAction(restore)
        alert.addAction(notNow)
        
        viewController.present(alert, animated: true, completion: nil)
    }
    
    static func upgrade(thenCall completion: ((Bool) -> ())?) {
        SwiftyStoreKit.purchaseProduct(upgradeProductId, atomically: true) { result in
            switch result {
            case .success:
                upgraded = true
                completion?(true)
            case .error(let error):
                NSLog("Purchase of product \(upgradeProductId) failed. Error: \(error.localizedDescription)")
            }
        }
    }
    
    static func restore(thenCall completion: ((Bool) -> ())?) {
        SwiftyStoreKit.restorePurchases(atomically: true) { result in
            if let product = result.restoredPurchases.first,
                product.productId == upgradeProductId {
                upgraded = true
                completion?(true)
            }
            else {
                NSLog("Product Restore failed.")
                completion?(false)
            }
        }
    }
    
    static func completeTransactions() {
        SwiftyStoreKit.completeTransactions(atomically: true) { products in
            for product in products {
                if product.transaction.transactionState == .purchased ||
                    product.transaction.transactionState == .restored {
                    upgraded = true
                    if product.needsFinishTransaction {
                        SwiftyStoreKit.finishTransaction(product.transaction)
                    }
                }
            }
        }
    }
}

extension UpgradeManager {
    static func registerAppLaunch() {
        let count = userDefaults.integer(forKey: Key.appLaunchCountMod3)
        let newCount = (count + 1) % 3
        
        userDefaults.set(newCount, forKey: Key.appLaunchCountMod3)
        userDefaults.synchronize()
    }
    
    static func maybePromptForReview() {
        let count = userDefaults.integer(forKey: Key.appLaunchCountMod3)
        if count == 0 {
            SKStoreReviewController.requestReview()
        }
    }
}
