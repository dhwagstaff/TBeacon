//
//  OpenFoodFactsProduct.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/10/25.
//

import Foundation

// MARK: - Open Food Facts API Response Model
struct OpenFoodFactsResponse: Codable {
    let product: OpenFoodFactsProduct?
}

struct OpenFoodFactsProduct: Codable {
    let code: String?
    let product_name: String?
    let brands: String?
    let categories: String?
    let price: String?
    let expiration_date: String?
    let image_url: String?
    let image_front_url: String?
    let image_thumb_url: String?
}
