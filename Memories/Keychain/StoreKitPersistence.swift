//
// Created by Michael Brown on 21/04/2017.
// Copyright (c) 2017 Michael Brown. All rights reserved.
//

import Foundation

struct StoreKitPersistence {
    let transactionsKey = "RMStoreTransactions"
    let keychain = KeychainSwift()

    func isPurchased(identifier: String) -> Bool {
        let transactions = keychain.getDictionary(for: transactionsKey)
        return transactions.keys.contains(identifier)
    }

    func persistPurchase(of identifier: String) {
        var transactions = keychain.getDictionary(for: transactionsKey)
        transactions[identifier] = true

        keychain.set(dictionary: transactions, for: transactionsKey)
    }
}