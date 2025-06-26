//
//  KeychainHelper.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/19/25.
//

import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    func save(_ data: Data, service: String, account: String) {
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary
        
        // First try to update existing item
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        
        if status == errSecItemNotFound {
            // No existing item found, add a new one
            status = SecItemAdd(query, nil)
        }
        
        if status != errSecSuccess {
            print("Error saving to Keychain: \(status)")
        }
    }
    
    func read(service: String, account: String) -> Data? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        return result as? Data
    }
    
    // Add this method to your KeychainHelper class
    func delete(service: String, account: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary
        
        let status = SecItemDelete(query)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Error deleting from Keychain: \(status)")
        } else {
            print("Successfully deleted from Keychain")
        }
    }
}
