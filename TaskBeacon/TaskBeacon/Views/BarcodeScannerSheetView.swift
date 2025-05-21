//
//  BarcodeScannerSheetView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/8/25.
//

import SwiftUI

struct BarcodeScannerSheetView: View {
    @Binding var isScanning: Bool
    @Binding var selectedProduct: ShoppingItemEntity?
    @Binding var showErrorMessage: String?

    @ObservedObject var barcodeScannerViewModel: BarcodeScannerViewModel

    var body: some View {
        Color.clear
            .background(Color(.systemBackground)) // ✅ Ensure base color follows theme
            .fullScreenCover(isPresented: $isScanning) {
                BarcodeScannerView { barcode in
                    isScanning = false

                    barcodeScannerViewModel.fetchProductDetails(barcode: barcode) { product in
                        DispatchQueue.main.async {
                            if let product = product {
                                selectedProduct = product
                            } else {
                                showErrorMessage = "Product not found."
                            }
                        }
                    }
                } onCancel: {
                    isScanning = false
                }
            }
    }
}

//struct BarcodeScannerSheetView: View {
//    @Binding var isScanning: Bool
//    @Binding var selectedProduct: ShoppingItem?
//    @Binding var showErrorMessage: String?
//
//    @ObservedObject var barcodeScannerViewModel: BarcodeScannerViewModel
//
//    var body: some View {
//        Color.clear // Prevents layout issues
//            .fullScreenCover(isPresented: $isScanning) {
//                BarcodeScannerView { barcode in
//                    isScanning = false
//                    
//                    barcodeScannerViewModel.fetchProductDetails(barcode: barcode) { product in
//                        DispatchQueue.main.async {
//                            if let product = product {
//                                selectedProduct = product // ✅ Directly assign the product
//                            } else {
//                                showErrorMessage = "Product not found."
//                            }
//                        }
//                    }
//                } onCancel: {
//                    isScanning = false
//                }
//            }
//    }
//}

//#Preview {
//    BarcodeScannerSheetView(isScanning: .constant(true), barcodeScannerViewModel: BarcodeScannerViewModel())
//}
