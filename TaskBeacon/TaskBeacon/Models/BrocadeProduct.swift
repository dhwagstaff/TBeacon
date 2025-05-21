//
//  BrocadeProduct.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/10/25.
//

import Foundation

// MARK: - Brocade.io API Response Model
struct BrocadeProduct: Codable {
    let id: Int
    let gtin: String
    let gtin_encoding: String
    let name: String
    let brand_name: String
    let properties: ProductProperties  // ✅ Not optional since it's always present
    let source: String
    let created_at: String
    let updated_at: String
}

// ✅ Ensure correct types match JSON
struct ProductProperties: Codable {
    let volume_ml: Double?
    let unit_count: Int
}

//struct BrocadeResponse: Codable {
//    let products: [BrocadeProduct]?
//}
//
//struct BrocadeProduct: Codable {
//    let id: Int
//    let gtin: String
//    let gtin_encoding: String
//    let name: String
//    let brand_name: String
//    let properties: ProductProperties
//    let source: String
//    let created_at: String
//    let updated_at: String
//
//    enum CodingKeys: String, CodingKey {
//        case id
//        case gtin
//        case gtin_encoding
//        case name
//        case brand_name
//        case properties
//        case source
//        case created_at
//        case updated_at
//    }
//}
//
//// Properties struct
//struct ProductProperties: Codable {
//    let volume_ml: Double
//    let unit_count: Int
//}
//
