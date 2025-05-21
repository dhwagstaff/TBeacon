//
//  ProductInfoView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/8/25.
//

import SwiftUI

struct ProductInfoView: View {
    let product: Product
    let stores: [StoreOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scanned Product")
                .font(.headline)
                .foregroundColor(.primary)

            Text(product.name.isEmpty ? "Unknown Product" : product.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Brand: \(product.brand ?? "Not Available")")
                .font(.subheadline)
                .foregroundColor(.primary)

            Text("Category: \(product.category ?? "Not Available")")
                .font(.subheadline)
                .foregroundColor(.primary)

            if stores.isEmpty {
                Text("Fetching store prices...")
                    .italic()
                    .foregroundColor(.secondary) // ✅ adapts to theme
            } else {
                Text("Best Prices Nearby:")
                    .font(.headline)
                    .foregroundColor(.primary)

                ForEach(stores, id: \.id) { store in
                    Text("\(store.name): \(store.price, format: .currency(code: "USD"))")
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground)) // ✅ adapts to theme
    }
}


//struct ProductInfoView: View {
//    let product: Product
//    let stores: [StoreOption]
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            Text("Scanned Product")
//                .font(.headline)
//
//            Text(product.name.isEmpty ? "Unknown Product" : product.name)
//                .font(.title2)
//                .fontWeight(.bold)
//
//            Text("Brand: \(product.brand ?? "Not Available")")
//                .font(.subheadline)
//
//            Text("Category: \(product.category ?? "Not Available")")
//                .font(.subheadline)
//
//            if stores.isEmpty {
//                Text("Fetching store prices...")
//                    .italic()
//                    .foregroundColor(.gray)
//            } else {
//                Text("Best Prices Nearby:")
//                    .font(.headline)
//                
//                ForEach(stores, id: \.id) { store in
//                    Text("\(store.name): \(store.price, format: .currency(code: "USD"))")
//                }
//            }
//        }
//        .padding()
//    }
//}

//#Preview {
//    ProductInfoView()
//}
