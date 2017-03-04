//
//  Keychain.swift
//  Memories
//
//  Created by Michael Brown on 01/03/2017.
//  Copyright © 2017 Michael Brown. All rights reserved.
//

import Foundation
import Security

class KeychainSwift {
    /**
    Retrieves the data from the keychain that corresponds to the given key.
    
    - parameter key: The key that is used to read the keychain item.
    - returns: The text value from the keychain. Returns nil if unable to read the item.
    
    */
    static func getData(for key: String) -> Data? {
        let query: [String: Any] = [
            KeychainSwiftConstants.klass       : kSecClassGenericPassword,
            KeychainSwiftConstants.attrAccount : key,
            KeychainSwiftConstants.attrGeneric : key,
            KeychainSwiftConstants.attrService : Bundle.main.bundleIdentifier!,
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
    
    static func getDictionary(for key: String) -> [String : Any] {
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
    
}
