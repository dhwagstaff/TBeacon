//
//  CategoryPickerView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 4/22/25.
//

import SwiftUI

struct CategoryPickerSection: View {
    @Environment(\.presentationMode) private var presentationMode

    @Binding var selectedCategoryEmoji: String
    @Binding var selectedCategory: String
    @Binding var selectedCategoryFromGroceryFood: Bool
    
    @State private var showCategorySelection: Bool = false
    
    var body: some View {
        RoundedSectionBackground(title: "Category", iconName: "tag") {
            Button(action: { showCategorySelection = true }) {
                HStack {
                    if let symbol = Constants.groceryFoodCategoryIcons[selectedCategory], UIImage(systemName: symbol) != nil {
                        Text("symbol : \(symbol)")
                        Image(systemName: symbol)
                            .foregroundColor(Constants.shoppingCategoryColors[selectedCategory] ?? .primary)
                    } else {
                        let emoji = selectedCategoryFromGroceryFood
                            ? Constants.groceryFoodCategoryIcons[selectedCategory]
                            : Constants.shoppingCategoryIcons[selectedCategory]
                        Text(emoji ?? "🛍️").font(.title)
                    }
                    
                    Text(selectedCategory.isEmpty ? Constants.selectCategory : selectedCategory)
                        .foregroundColor(selectedCategory.isEmpty ? .secondary : .primary)
                    
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .sheet(isPresented: $showCategorySelection, onDismiss: {
            }) {
                CategorySelectionView(selectedCategoryEmoji: $selectedCategoryEmoji,
                                      selectedCategory: $selectedCategory,
                                      showCategorySelection: $showCategorySelection,
                                      selectedCategoryFromGroceryFood: $selectedCategoryFromGroceryFood)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: true)
    }
}
