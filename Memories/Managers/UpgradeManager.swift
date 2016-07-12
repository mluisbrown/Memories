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
    
    static private var priceFormatter : NumberFormatter = {
        var formatter = NumberFormatter()
        formatter.formatterBehavior = .behavior10_4
        formatter.numberStyle = .currency
        return formatter
    }()
    
    static private var transactionPersistor: RMStoreKeychainPersistence = RMStoreKeychainPersistence()
    
    static private var store : RMStore = {
        var rmstore = RMStore.default()
        rmstore?.transactionPersistor = transactionPersistor
        return rmstore!
    }()
    
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
        return transactionPersistor.isPurchasedProduct(ofIdentifier: upgradeProductId)
        }() {
        
        didSet {
            if upgraded {
                userDefaults.removeObject(forKey: Key.viewCountDate)
                userDefaults.removeObject(forKey: Key.highQualityViewCount)
                userDefaults.synchronize()
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

    static func getUpgradePrice(_ completion: ( @noescape (price: String?) -> ())?) {
        if let price = upgradePrice {
            completion?(price: price)
            return
        }
        
        store.requestProducts(Set([upgradeProductId]), success: { (products, invalidIds) -> Void in
            if products?.count > 0 {
                let product = products?.first as! SKProduct
                priceFormatter.locale = product.priceLocale
                upgradePrice = priceFormatter.string(from: product.price)!
                completion?(price: upgradePrice)
            }
        }) { (error) -> Void in
            NSLog("Unabled to obtain upgrade price. Error: \(error?.localizedDescription)")
            completion?(price: nil)
        }
    }
    
    /// returns whether the user is allowed to view another high quality image
    static func highQualityViewAllowed() -> Bool {
        if !upgraded { getUpgradePrice(nil) }
        return upgraded || highQualityViewCount < MaxHighQualityViewCount
    }
    
    /// prompts the user if they want to upgrade
    static func promptForUpgradeInViewController(_ viewController: UIViewController, completion: ((upgraded: Bool) -> ())?) {
        guard let price = upgradePrice where !upgradePromptShown else {
            completion?(upgraded: false)
            return
        }
        
        upgradePromptShown = true
        
        let upgradeTitle : String
        upgradeTitle = NSLocalizedString("Upgrade for ", comment: "") + price
        
        let alert = UIAlertController(title: NSLocalizedString("Five a Day Limit", comment: "")
            , message: NSLocalizedString("You can view 5 full quality photos per day which you can share, favorite or delete. You can Upgrade to remove this restriction. The Upgrade option is also available in the settings page.", comment: "")
            , preferredStyle: .alert)
        let upgrade = UIAlertAction(title: upgradeTitle, style: .default, handler: { (action) -> Void in
            UpgradeManager.upgrade(completion)
        })
        let restore = UIAlertAction(title: NSLocalizedString("Restore", comment: ""), style: .default, handler: { (action) -> Void in
            UpgradeManager.restore(completion)
        })
        let notNow = UIAlertAction(title: NSLocalizedString("Not Now", comment: ""), style: .cancel, handler: { (action) -> Void in
            completion?(upgraded: false)
        })
        alert.addAction(upgrade)
        alert.addAction(restore)
        alert.addAction(notNow)
        
        viewController.present(alert, animated: true, completion: nil)
    }
    
    static func upgrade(_ completion: ((success: Bool) -> ())?) {
        store.addPayment(upgradeProductId, success: { (transaction) -> Void in
            upgraded = true
            completion?(success: true)
        }) { (transaction, error) -> Void in
            completion?(success: false)
        }
    }
    
    static func restore(_ completion: ((success: Bool) -> ())?) {
        store.restoreTransactions( onSuccess: { (transactions) -> Void in
            guard transactions?.count > 0,
                let transaction = transactions?[0] as? SKPaymentTransaction
                where transaction.payment.productIdentifier == upgradeProductId else {
                    completion?(success: false)
                    return
            }

            upgraded = true
            completion?(success: true)
        }) { (error) -> Void in
            completion?(success: false)
        }
    }
}
