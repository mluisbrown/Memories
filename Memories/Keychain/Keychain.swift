//
//  Keychain.swift
//  Memories
//
//  Created by Michael Brown on 01/03/2017.
//  Copyright © 2017 Michael Brown. All rights reserved.
//

import Foundation
import Security

struct KeychainSwift {
    /**
    Retrieves the data from the keychain that corresponds to the given key.
    
    - parameter key: The key that is used to read the keychain item.
    - returns: The text value from the keychain. Returns nil if unable to read the item.
    
    */
    func getData(for key: String) -> Data? {
        let query: [String: Any] = [
            KeychainSwiftConstants.klass       : kSecClassGenericPassword,
            KeychainSwiftConstants.attrAccount : key,
            KeychainSwiftConstants.attrGeneric : key,
            KeychainSwiftConstants.attrService : Bundle.main.bundleIdentifier ?? "",
            KeychainSwiftConstants.returnData  : kCFBooleanTrue,
            KeychainSwiftConstants.matchLimit  : kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        
        let resultCode = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        
        guard resultCode == noErr else {
            return nil
        }
        
        return result as? Data
    }
    
    /**
     
     Stores the data in the keychain item under the given key.
     
     - parameter key: Key under which the data is stored in the keychain.
     - parameter value: Data to be written to the keychain.
     - returns: True if the text was successfully written to the keychain.
     
     */
    @discardableResult
    func set(data value: Data, for key: String) -> Bool {
        
        delete(key: key) // Delete any existing key before saving it
        
        let query: [String : Any] = [
            KeychainSwiftConstants.klass       : kSecClassGenericPassword,
            KeychainSwiftConstants.attrAccount : key,
            KeychainSwiftConstants.attrGeneric : key,
            KeychainSwiftConstants.valueData   : value,
            KeychainSwiftConstants.attrService : Bundle.main.bundleIdentifier ?? "",
            KeychainSwiftConstants.accessible  : kSecAttrAccessibleWhenUnlocked
        ]
        
        let resultCode = SecItemAdd(query as CFDictionary, nil)
        
        return resultCode == noErr
    }
    
    
    /**
     Deletes the single keychain item specified by the key.
     
     - parameter key: The key that is used to delete the keychain item.
     - returns: True if the item was successfully deleted.
     
     */
    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            KeychainSwiftConstants.klass       : kSecClassGenericPassword,
            KeychainSwiftConstants.attrAccount : key,
            KeychainSwiftConstants.attrGeneric : key,
            KeychainSwiftConstants.attrService : Bundle.main.bundleIdentifier ?? ""
        ]
        
        let resultCode = SecItemDelete(query as CFDictionary)
        
        return resultCode == noErr
    }
    
    func getDictionary(for key: String) -> [String : Any] {
        guard let data = getData(for: key) else {
            return [:]
        }
        
        do {
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String : Any] else {
                return [:]
            }
            
            return dict
        } catch {
            return [:]
        }
    }
    
    func set(dictionary: [String : Any], for key: String) {
        do {
            let data = try JSONSerialization.data(withJSONObject: dictionary)
            set(data: data, for: key)
        } catch {
            NSLog("Error: Unable to set data for keychain key \(key)")
        }
    }
}
