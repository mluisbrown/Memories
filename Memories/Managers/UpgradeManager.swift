//
//  UpgradeManager.swift
//  Memories
//
//  Created by Michael Brown on 30/09/2015.
//  Copyright © 2015 Michael Brown. All rights reserved.
//

import Foundation
import Security
import RMStore

class UpgradeManager {
    static let upgradeProductId = "com.luacheia.memories.Upgrade"
    
    struct Key {
        static let highQualityViewCount = "HighQualityViewCount"
        static let viewCountDate = "ViewCountDate"
        static let upgradePromptShown = "UpgradePromptShown"
    }
    
    static let MaxHighQualityViewCount = 5
    
    static private let userDefaults = UserDefaults.standard
    
    static private let priceFormatter = NumberFormatter().with {
        $0.formatterBehavior = .behavior10_4
        $0.numberStyle = .currency
    }
    
    static private let store: RMStore = RMStore.default()
    
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
        return StoreKitPersistence().isPurchased(identifier: upgradeProductId)
        }() {
        
        didSet {
            if upgraded {
                userDefaults.removeObject(forKey: Key.viewCountDate)
                userDefaults.removeObject(forKey: Key.highQualityViewCount)
                userDefaults.synchronize()
                
                StoreKitPersistence().persistPurchase(of: upgradeProductId)
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
        
        store.requestProducts(Set([upgradeProductId]), success: { (products, invalidIds) -> Void in
            if let products = products, products.count > 0 {
                let product = products.first as! SKProduct
                priceFormatter.locale = product.priceLocale
                upgradePrice = priceFormatter.string(from: product.price)!
                completion?(upgradePrice)
            }
        }) { (error) -> Void in
            NSLog("Unabled to obtain upgrade price. Error: \(error?.localizedDescription ?? "Error description not available.")")
            completion?(nil)
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
        store.addPayment(upgradeProductId, success: { (transaction) -> Void in
            upgraded = true
            completion?(true)
        }) { (transaction, error) -> Void in
            completion?(false)
        }
    }
    
    static func restore(thenCall completion: ((Bool) -> ())?) {
        store.restoreTransactions( onSuccess: { (transactions) -> Void in
            guard let transactions = transactions,
                transactions.count > 0,
                let transaction = transactions[0] as? SKPaymentTransaction,
                transaction.payment.productIdentifier == upgradeProductId else {
                    completion?(false)
                    return
            }

            upgraded = true
            completion?(true)
        }) { (error) -> Void in
            completion?(false)
        }
    }
}
