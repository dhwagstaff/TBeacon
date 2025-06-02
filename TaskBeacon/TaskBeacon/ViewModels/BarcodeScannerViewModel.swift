//
//  BarcodeScannerViewModel.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/7/25.
//

import AVFoundation
import CoreData
import CoreLocation
import SwiftUI

class BarcodeScannerViewModel: ListsViewModel, CLLocationManagerDelegate {
    private let locationManager = LocationManager.shared

    @Published var userLatitude: Double?
    @Published var userLongitude: Double?
    @Published var scannedProductName: String? = nil
    @Published var isLoading: Bool = false
    @Published var availableStores: [StoreOption] = []
    @Published var showStoreSelectionSheet: Bool = false
    @Published var showErrorMessage: String?
    
    var captureSession: AVCaptureSession?
    
    override init() {
        super.init()
        
        locationManager.onLocationUpdate = { [weak self] coordinate in
            DispatchQueue.main.async {
                self?.userLatitude = coordinate.latitude
                self?.userLongitude = coordinate.longitude
            }
        }
        
        setupScanner()
    }
    
    private func setupScanner() {
        DispatchQueue.global(qos: .userInitiated).async {
            let session = self.setupCaptureSession()
            DispatchQueue.main.async {
                self.captureSession = session
            }
        }
    }
    
    func setupCaptureSession() -> AVCaptureSession? {
        let captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("❌ No video capture device found.")
            return nil
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                print("❌ Cannot add video input to session.")
                return nil
            }
        } catch {
            print("❌ Error creating video input: \(error.localizedDescription)")
            
            self.errorMessage = error.localizedDescription
            self.showErrorAlert = true
            
            return nil
        }

        return captureSession
    }
    
    func fetchProductDetails(barcode: String, completion: @escaping (ShoppingItemEntity?) -> Void) {
        isLoading = true
        let openFoodFactsURL = "https://world.openfoodfacts.org/api/v2/product/\(barcode).json"

        guard let url = URL(string: openFoodFactsURL) else {
            print("❌ Invalid URL for OpenFoodFacts")
            fetchFromBrocade(barcode: barcode, completion: completion) // ✅ Fallback
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                print("⚠️ OpenFoodFacts request failed. Attempting Brocade...")
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
                
                DispatchQueue.main.async { self.fetchFromBrocade(barcode: barcode, completion: completion) }
                return
            }

            do {
                let result = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
                guard let productData = result.product else {
                    print("⚠️ Product not found on OpenFoodFacts, attempting Brocade...")
                    DispatchQueue.main.async { self.fetchFromBrocade(barcode: barcode, completion: completion) }
                    return
                }

                let category = determineBarcodeCategory(for: productData.product_name ?? "Unknown", apiCategory: productData.categories)

                    let context = PersistenceController.shared.container.viewContext
                    let newItem = ShoppingItemEntity(context: context)

                newItem.uid = UUID().uuidString
                    newItem.gtin = productData.code ?? barcode
                    newItem.barcode = barcode
                    newItem.name = productData.product_name
                    newItem.brand = productData.brands
                    newItem.category = category
                    newItem.price = Double(productData.price ?? "0.0") ?? 0.0
                    newItem.dateAdded = Date()
                    newItem.lastUpdated = Date()
                    newItem.lastEditor = "User"
                    newItem.isCompleted = false
                    newItem.priority = 2

                    // ✅ Handle Expiration Date
                if let expirationDateString = productData.expiration_date {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    if let expirationDate = dateFormatter.date(from: expirationDateString) {
                        newItem.expirationDate = expirationDate
                    }
                } else if let categoryDict = Constants.expirationEstimates[category] {
                    // Get the product name for matching
                    let productName = (productData.product_name ?? "").lowercased()
                    
                    // Search through all subcategories for a matching item
                    var foundMatch = false
                    for (_, subcategoryItems) in categoryDict {
                        // Try to find a matching item in this subcategory
                        if let matchingItem = subcategoryItems.first(where: { (itemName, _) in
                            productName.contains(itemName.lowercased())
                        }) {
                            // Found a match, set the expiration date
                            let (_, daysToExpire) = matchingItem
                            newItem.expirationDate = Calendar.current.date(byAdding: .day, value: daysToExpire, to: Date())
                            foundMatch = true
                            print("📅 Found matching item '\(matchingItem.0)' in category '\(category)', setting expiration to \(daysToExpire) days")
                            break
                        }
                    }
                    
                    // If no match found, use category default
                    if !foundMatch {
                        if let defaultDays = Constants.getDefaultExpirationDays(for: category) {
                            newItem.expirationDate = Calendar.current.date(byAdding: .day, value: defaultDays, to: Date())
                            print("📅 No specific match found, using default expiration of \(defaultDays) days for category '\(category)'")
                        } else {
                            newItem.expirationDate = nil
                            print("⚠️ No expiration estimate found for category '\(category)'")
                        }
                    }
                } else {
                    newItem.expirationDate = nil
                    print("⚠️ No expiration estimates found for category '\(category)'")
                }
                
                    // ✅ Fetch and Assign Product Image
                    if let imageUrl = productData.image_url ?? productData.image_thumb_url {
                        self.fetchProductImage(from: imageUrl, completion: { imageData in
                            DispatchQueue.main.async {
                                newItem.productImage = imageData ?? UIImage(systemName: "storefront.circle.fill")?.pngData()
                                try? context.save()
                            }
                        })
                    } else {
                        newItem.productImage = UIImage(systemName: "storefront.circle.fill")?.pngData()
                        try? context.save()
                    }

                    let shoppingListViewModel = ShoppingListViewModel(context: context)
                
//                Task {
//                    await shoppingListViewModel.saveShoppingItemToCoreData(item: newItem)
//                }

                    // ✅ **Trigger Immediate UI Refresh**
                    DispatchQueue.main.async {
                        shoppingListViewModel.fetchShoppingItems()
                        shoppingListViewModel.updateGroupedItemsByStoreAndCategory(updateExists: true)

                        // ✅ Notify UI about the update
                        NotificationCenter.default.post(name: ShoppingNotification.shoppingListUpdated.name, object: nil)

                        completion(newItem)
                    }
               // }
            } catch {
                print("❌ Error decoding JSON: \(error.localizedDescription). Fetching from Brocade...")
                
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true
                
                DispatchQueue.main.async { self.fetchFromBrocade(barcode: barcode, completion: completion) }
            }
        }.resume()
    }
    
    // ✅ New method to notify ViewModel that a new item was added
    private func refreshShoppingList() {
        NotificationCenter.default.post(name: ShoppingNotification.shoppingListUpdated.name, object: nil)
    }
    
    private func fetchProductImage(from url: String?, completion: @escaping (Data?) -> Void) {
        guard let urlString = url, let imageUrl = URL(string: urlString) else {
            print("❌ Invalid or missing image URL. Using placeholder.")
            
            self.errorMessage = "❌ Invalid or missing image URL. Using placeholder."
            self.showErrorAlert = true
            
            completion(nil) // ✅ Return nil, UI will handle default image
            return
        }

        URLSession.shared.dataTask(with: imageUrl) { data, _, error in
            if let data = data, error == nil {
                completion(data) // ✅ Successfully downloaded image
            } else {
                print("⚠️ Failed to download image: \(error?.localizedDescription ?? "Unknown error")")
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }

                completion(nil) // ✅ Return nil, UI will handle default image
            }
        }.resume()
    }

    func fetchNearbyStorePrices(for product: Product, completion: @escaping ([StoreOption]) -> Void) {
        let urlString = "https://api.zinc.io/v1/products/\(product.gtin)/pricing?lat=\(userLatitude ?? 0.0)&lon=\(userLongitude ?? 0.0)&radius=40"

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion([])
                return
            }

            do {
                let response = try JSONDecoder().decode(StorePriceResponse.self, from: data)
                let sortedStores = response.stores.sorted { $0.price < $1.price }
                completion(Array(sortedStores.prefix(3))) // ✅ Only return the top 3 cheapest stores
            } catch {
                print("❌ Error decoding store price data: \(error)")
                
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true

                completion([])
            }
        }.resume()
    }
    
    func fetchFromBrocade(barcode: String, completion: @escaping (ShoppingItemEntity?) -> Void) {
        guard let brocadeURL = URL(string: "https://www.brocade.io/api/items/\(barcode)") else {
            print("❌ Invalid Brocade API URL")
            
            self.errorMessage = "❌ Invalid Brocade API URL"
            self.showErrorAlert = true

            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        URLSession.shared.dataTask(with: brocadeURL) { data, _, error in
            if let error = error {
                print("❌ Error fetching data from Brocade: \(error.localizedDescription)")
                
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true

                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            guard let data = data else {
                print("❌ No data received from Brocade")
                
                self.errorMessage = "❌ No data received from Brocade"
                self.showErrorAlert = true

                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            do {
                let brocadeProduct = try JSONDecoder().decode(BrocadeProduct.self, from: data)
                
                let context = PersistenceController.shared.container.viewContext
                
                let category = determineBarcodeCategory(for: brocadeProduct.name, apiCategory: nil)
                
                let newItem = ShoppingItemEntity(context: context)
                newItem.uid = UUID().uuidString
                newItem.gtin = brocadeProduct.gtin
                newItem.barcode = barcode
                newItem.name = brocadeProduct.name
                newItem.brand = brocadeProduct.brand_name
                newItem.category = category
                newItem.price = 0
                newItem.volume = brocadeProduct.properties.volume_ml ?? 0.0
                newItem.unitCount = Int16(brocadeProduct.properties.unit_count)
                
                // ✅ Assign placeholder image since Brocade has NO product images
                newItem.productImage = UIImage(systemName: "storefront.circle.fill")?.pngData()
                
                do {
                    let viewModel = ShoppingListViewModel(context: context)
                    
//                    Task {
//                        await viewModel.saveShoppingItemToCoreData(item: newItem)
//                    }
                    
                    // ✅ **Trigger Immediate UI Refresh**
                    viewModel.fetchShoppingItems()
                    viewModel.updateGroupedItemsByStoreAndCategory(updateExists: true)
                    
                    // ✅ Notify UI about the update
                    NotificationCenter.default.post(name: ShoppingNotification.shoppingListUpdated.name, object: nil)
                    
                    completion(newItem)
                } catch {
                    print("❌ Error saving shopping item: \(error.localizedDescription)")
                    
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true

                    completion(nil)
                    return
                }
                //  }
            } catch {
                print("❌ JSON Decoding Error from Brocade: \(error.localizedDescription)")
                
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true

                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }.resume()
    }
}
