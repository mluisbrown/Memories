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
    static let UpgradeProductId = "com.luacheia.memories.Upgrade"
    static let HighQualityViewCountKey = "HighQualityViewCount"
    static let ViewCountDateKey = "ViewCountDate"
    static let UpgradePromptShownKey = "UpgradePromptShown"
    
    static let MaxHighQualityViewCount = 5
    
    static private let userDefaults = NSUserDefaults.standardUserDefaults()
    
    static private var priceFormatter : NSNumberFormatter = {
        var formatter = NSNumberFormatter()
        formatter.formatterBehavior = .Behavior10_4
        formatter.numberStyle = .CurrencyStyle
        return formatter
    }()
    
    static private var transactionPersistor: RMStoreKeychainPersistence = RMStoreKeychainPersistence()
    
    static private var store : RMStore = {
        var rmstore = RMStore.defaultStore()
        rmstore.transactionPersistor = transactionPersistor
        return rmstore
    }()
    
    /// flag to indicate if the user been shown the upgrade prompt since starting the app
    static private var upgradePromptShown : Bool {
        get {
            return userDefaults.boolForKey(UpgradePromptShownKey)
        }
        
        set {
            userDefaults.setBool(newValue, forKey: UpgradePromptShownKey)
            userDefaults.synchronize()
        }
    }

    /// the localized upgrade price
    static var upgradePrice : String?
    
    /// flag to indicate if the user upgraded the app
    static var upgraded : Bool = {
        return transactionPersistor.isPurchasedProductOfIdentifier(UpgradeProductId)
        }() {
        
        didSet {
            if upgraded {
                userDefaults.removeObjectForKey(ViewCountDateKey)
                userDefaults.removeObjectForKey(HighQualityViewCountKey)
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
            let today = NSDate()
        
            if let date = userDefaults.objectForKey(ViewCountDateKey) as? NSDate {
                let day = NSCalendar.currentCalendar().ordinalityOfUnit(.Day, inUnit: .Era, forDate: date)
                let now = NSCalendar.currentCalendar().ordinalityOfUnit(.Day, inUnit: .Era, forDate: today)
        
                if day != now {
                    userDefaults.setObject(today, forKey: ViewCountDateKey)
                    userDefaults.setInteger(0, forKey: HighQualityViewCountKey)
                    userDefaults.setBool(false, forKey: UpgradePromptShownKey)
                } else {
                    count = userDefaults.integerForKey(HighQualityViewCountKey)
                }
            } else {
                userDefaults.setObject(today, forKey: ViewCountDateKey)
                userDefaults.setInteger(0, forKey: HighQualityViewCountKey)
                userDefaults.setBool(false, forKey: UpgradePromptShownKey)
            }
            
            userDefaults.synchronize()
            return count
        }
        
        set {
            guard !upgraded else {
                return
            }
            
            userDefaults.setInteger(newValue, forKey: HighQualityViewCountKey)
            userDefaults.synchronize()
        }
    }

    static func getUpgradePrice(completion: ((price: String?) -> ())?) {
        if let price = upgradePrice {
            completion?(price: price)
            return
        }
        
        store.requestProducts(Set([UpgradeProductId]), success: { (products, invalidIds) -> Void in
            if products.count > 0 {
                let product = products.first as! SKProduct
                priceFormatter.locale = product.priceLocale
                upgradePrice = priceFormatter.stringFromNumber(product.price)!
                completion?(price: upgradePrice)
            }
        }) { (error) -> Void in
            NSLog("Unabled to obtain upgrade price. Error: \(error.localizedDescription)")
            completion?(price: nil)
        }
    }
    
    /// returns whether the user is allowed to view another high quality image
    static func highQualityViewAllowed() -> Bool {
        if !upgraded { getUpgradePrice(nil) }
        return upgraded || highQualityViewCount < MaxHighQualityViewCount
    }
    
    /// prompts the user if they want to upgrade
    static func promptForUpgradeInViewController(viewController: UIViewController, completion: ((upgraded: Bool) -> ())?) {
        guard let price = upgradePrice where !upgradePromptShown else {
            completion?(upgraded: false)
            return
        }
        
        upgradePromptShown = true
        
        let upgradeTitle : String
        upgradeTitle = NSLocalizedString("Upgrade for ", comment: "") + price
        
        let alert = UIAlertController(title: NSLocalizedString("Five a Day Limit", comment: "")
            , message: NSLocalizedString("You can view 5 full quality photos per day which you can zoom, share or delete. You can Upgrade to remove this restriction. The Upgrade option is also available in the settings page.", comment: "")
            , preferredStyle: .Alert)
        let upgrade = UIAlertAction(title: upgradeTitle, style: .Default, handler: { (action) -> Void in
            UpgradeManager.upgrade(completion)
        })
        let restore = UIAlertAction(title: NSLocalizedString("Restore", comment: ""), style: .Default, handler: { (action) -> Void in
            UpgradeManager.restore(completion)
        })
        let notNow = UIAlertAction(title: NSLocalizedString("Not Now", comment: ""), style: .Cancel, handler: { (action) -> Void in
            completion?(upgraded: false)
        })
        alert.addAction(upgrade)
        alert.addAction(restore)
        alert.addAction(notNow)
        
        viewController.presentViewController(alert, animated: true, completion: nil)
    }
    
    static func upgrade(completion: ((success: Bool) -> ())?) {
#if (arch(i386) || arch(x86_64)) && os(iOS)
        upgraded = true
        completion?(success: true)
#else
        store.addPayment(UpgradeProductId, success: { (transaction) -> Void in
            upgraded = true
            completion?(success: true)
        }) { (transaction, error) -> Void in
            completion?(success: false)
        }
#endif
    }
    
    static func restore(completion: ((success: Bool) -> ())?) {
#if (arch(i386) || arch(x86_64)) && os(iOS)
        upgraded = true
        completion?(success: true)
#else
        store.restoreTransactionsOnSuccess( { (transactions) -> Void in
            upgraded = true
            completion?(success: true)
        }) { (error) -> Void in
            completion?(success: false)
        }
#endif
    }
}