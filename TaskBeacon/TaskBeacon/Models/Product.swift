//
//  Product.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/8/25.
//

import Foundation

struct Product: Identifiable, Codable {
    var id: String { gtin }
    var gtin: String
    let barcode: String
    let name: String
    let brand: String?
    let category: String?
    let price: String?
    let expirationDate: String?
    var thumbnailImage: String?
}
