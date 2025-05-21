//
//  OpenFoodFactsAPIViewModel.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/14/25.
//

import Foundation

class OpenFoodFactsApiViewModel {
    
    // COMMENTED OUT DUE TO NOT CURRENT USED
    
//    static func fetchProduct(barcode: String, completion: @escaping (Product?) -> Void) {
//        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
//
//        guard let url = URL(string: urlString) else {
//            print("❌ Invalid URL")
//            completion(nil)
//            return
//        }
//
//        URLSession.shared.dataTask(with: url) { data, response, error in
//            guard let data = data, error == nil else {
//                print("❌ Network error: \(error?.localizedDescription ?? "Unknown error")")
//                completion(nil)
//                return
//            }
//
//            do {
//                let decodedResponse = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
//
//                if let openFoodProduct = decodedResponse.product {
//                    // 🔹 Handle Expiration Date (API Value or Estimated)
//                    let expirationDate: String
//                    if let actualExpiration = openFoodProduct.expiration_date {
//                        expirationDate = actualExpiration // ✅ Use API expiration date if available
//                    } else if let category = openFoodProduct.categories,
//                              let days = Constants.expirationEstimates[category] {
//                     // dhw hold   let estimatedDate = Calendar.current.date(byAdding: .day, value: days, to: Date())
////                        let dateFormatter = DateFormatter()
////                        dateFormatter.dateFormat = "yyyy-MM-dd"
////                        expirationDate = dateFormatter.string(from: estimatedDate!)
//                    } else {
//                        expirationDate = "Unknown" // ✅ Fallback if no data is available
//                    }
//
//                    let product = Product(
//                        gtin: openFoodProduct.code ?? barcode,
//                        barcode: barcode,
//                        name: openFoodProduct.product_name ?? "Unknown Product",
//                        brand: openFoodProduct.brands,
//                        category: openFoodProduct.categories,
//                        price: openFoodProduct.price,
//                   //     expirationDate: expirationDate, // ✅ Now includes calculated expiration date
//                        thumbnailImage: nil
//                    )
//                    completion(product)
//                } else {
//                    print("❌ No product found in OpenFoodFacts")
//                    completion(nil)
//                }
//            } catch {
//                print("❌ JSON Decoding Error: \(error.localizedDescription)")
//                completion(nil)
//            }
//        }.resume()
//    }
}
