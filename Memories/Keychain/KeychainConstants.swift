//
//  KeychainConstants.swift
//  Memories
//
//  Created by Michael Brown on 01/03/2017.
//  Copyright © 2017 Michael Brown. All rights reserved.
//

import Foundation
import Security

/// Swift versions of Keychain constants
public struct KeychainConstants {
    /// Specifies a Keychain access group. Used for sharing Keychain items between apps.
    public static var accessGroup: String { return toString(kSecAttrAccessGroup) }
    
    /**
     A value that indicates when your app needs access to the data in a keychain item. The default value is AccessibleWhenUnlocked. 
     For a list of possible values, see KeychainSwiftAccessOptions.
     */
    public static var accessible: String { return toString(kSecAttrAccessible) }
    
    /// Used for specifying a String key when setting/getting a Keychain value.
    public static var attrAccount: String { return toString(kSecAttrAccount) }
    
    /// A user defined String key used when setting/getting a Keychain value.
    public static var attrGeneric: String { return toString(kSecAttrGeneric) }
    
    /// String key that represents the service associated with the item. Used when setting/getting a Keychain value.
    public static var attrService: String { return toString(kSecAttrService) }
    
    /// Used for specifying synchronization of keychain items between devices.
    public static var attrSynchronizable: String { return toString(kSecAttrSynchronizable) }
    
    /// An item class key used to construct a Keychain search dictionary.
    public static var klass: String { return toString(kSecClass) }
    
    /// Specifies the number of values returned from the keychain. The library only supports single values.
    public static var matchLimit: String { return toString(kSecMatchLimit) }
    
    /// A return data type used to get the data from the Keychain.
    public static var returnData: String { return toString(kSecReturnData) }
    
    /// Used for specifying a value when setting a Keychain value.
    public static var valueData: String { return toString(kSecValueData) }
    
    static func toString(_ value: CFString) -> String {
        return value as String
    }
}
