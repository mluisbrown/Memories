//
// Created by Michael Brown on 21/04/2017.
// Copyright (c) 2017 Michael Brown. All rights reserved.
//

import Foundation

struct StoreKitPersistence {
    static let transactionsKey = "RMStoreTransactions"

    static func isPurchased(identifier: String) -> Bool {
        let transactions = Keychain.getDictionary(for: transactionsKey)
        return transactions.keys.contains(identifier)
    }

    static func persistPurchase(of identifier: String) {
        var transactions = Keychain.getDictionary(for: transactionsKey)
        transactions[identifier] = true

        Keychain.set(dictionary: transactions, for: transactionsKey)
    }
}
