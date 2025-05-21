//
//  GroceryCategorySheet.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/21/25.
//

import SwiftUI

struct GroceryCategorySheet: View {
    @Binding var selectedCategoryEmoji: String
    @Binding var selectedCategory: String
    @Binding var showGrocerySheet: Bool
    
    var dismissCategorySheet: () -> Void

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Grocery & Food Categories").foregroundColor(.primary)) {
                    if let categories = Constants.departmentCategories[Constants.groceryAndFood] {
                        ForEach(categories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                                selectedCategoryEmoji = Constants.groceryFoodCategoryIcons[category] ??
                                                       Constants.shoppingCategoryIcons[category] ?? "🛍️"
                                
                                showGrocerySheet = false
                                
                                dismissCategorySheet()
                            } label: {
                                HStack {
                                    CategoryIcon(category: category)
                                    Text(category)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedCategory == category {
                                        Image(systemName: ImageSymbolNames.checkmarkCircleFill)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
            }
            .navigationTitle(Constants.groceryAndFood)
            .navigationBarItems(trailing: Button(Constants.cancel) {
                showGrocerySheet = false
            }.foregroundColor(.blue))
            .background(Color(.systemBackground)) // ⬅️ Dark-mode safe background
        }
    }

    private func CategoryIcon(category: String) -> some View {
        if let emojiOrSymbol = Constants.groceryFoodCategoryIcons[category] ?? Constants.shoppingCategoryIcons[category] {
            if UIImage(systemName: emojiOrSymbol) != nil {
                return AnyView(
                    Image(systemName: emojiOrSymbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(Constants.shoppingCategoryColors[category] ?? .gray)
                )
            } else {
                return AnyView(
                    Text(emojiOrSymbol)
                        .font(.title2)
                        .frame(width: 30, height: 30, alignment: .center)
                        .foregroundColor(.primary)
                )
            }
        } else {
            return AnyView(
                Text("🛍️")
                    .font(.title2)
                    .frame(width: 30, height: 30, alignment: .center)
                    .foregroundColor(.primary)
            )
        }
    }
}

//#Preview {
//    GroceryCategorySheet()
//}
