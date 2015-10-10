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
    
    /// the localized upgrade price
    static var upgradePrice = ""

    /// flag to indicate if the user been shown the upgrade prompt since starting the app
    static var upgradePromptShown = false

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
                } else {
                    count = userDefaults.integerForKey(HighQualityViewCountKey)
                }
            } else {
                userDefaults.setObject(today, forKey: ViewCountDateKey)
                userDefaults.setInteger(0, forKey: HighQualityViewCountKey)
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

    /// initialize RMStore and get the upgrade product price information
    static func initialize() {
        store.requestProducts(Set([UpgradeProductId]), success: { (products, invalidIds) -> Void in
            if products.count > 0 {
                let product = products.first as! SKProduct
                priceFormatter.locale = product.priceLocale
                upgradePrice = priceFormatter.stringFromNumber(product.price)!
            }
            }) { (error) -> Void in
                upgradePrice = ""
        }
    }
    
    /// returns whether the user is allowed to view another high quality image
    static func highQualityViewAllowed() -> Bool {
        return upgraded || highQualityViewCount < MaxHighQualityViewCount
    }
    
    /// prompts the user if they want to upgrade
    static func promptForUpgradeInViewController(viewController: UIViewController, completion: ((upgraded: Bool) -> ())?) {
        upgradePromptShown = true
        
        let alert = UIAlertController(title: NSLocalizedString("Five a Day Limit", comment: "")
            , message: NSLocalizedString("You can view 5 full quality photos per day, or you can Upgrade to remove this restriction which also enables the share button. The Upgrade option is also available in the settings page.\nIf you have already upgraded, tap Restore to restore your purchase.\nWould you like to upgrade now?", comment: "")
            , preferredStyle: .Alert)
        let upgrade = UIAlertAction(title: NSLocalizedString("Upgrade for ", comment: "") + upgradePrice, style: .Default, handler: { (action) -> Void in
            if let completion = completion {
                upgraded = true
                completion(upgraded: true)
            }
        })
        let restore = UIAlertAction(title: NSLocalizedString("Restore", comment: ""), style: .Default, handler: { (action) -> Void in
            if let completion = completion {
                completion(upgraded: true)
            }
        })
        let notNow = UIAlertAction(title: NSLocalizedString("Not Now", comment: ""), style: .Cancel, handler: { (action) -> Void in
            if let completion = completion {
                completion(upgraded: false)
            }
        })
        alert.addAction(upgrade)
        alert.addAction(restore)
        alert.addAction(notNow)
        
        viewController.presentViewController(alert, animated: true, completion: nil)
    }
    
    static func upgrade(completion: ((success: Bool) -> ())?) {
        store.addPayment(UpgradeProductId, success: { (transaction) -> Void in
            if let completion = completion {
                completion(success: true)
            }
        }) { (transaction, error) -> Void in
            if let completion = completion {
                completion(success: false)
            }
        }
    }
    
    static func restore(completion: ((success: Bool) -> ())?) {
        store.restoreTransactionsOnSuccess( { (transactions) -> Void in
            if let completion = completion {
                completion(success: true)
            }
        }) { (error) -> Void in
            if let completion = completion {
                completion(success: false)
            }
        }
    }
}