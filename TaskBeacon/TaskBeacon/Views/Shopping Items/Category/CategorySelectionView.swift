//
//  CategorySelectionView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 2/11/25.
//

import SwiftUI

struct CategorySelectionView: View {
    @Environment(\.presentationMode) private var presentationMode

    @Binding var selectedCategoryEmoji: String
    @Binding var selectedCategory: String
    @Binding var showCategorySelection: Bool
    @Binding var selectedCategoryFromGroceryFood: Bool

    @State private var customCategory: String = ""
    @State private var isCustomCategory: Bool = false
    @State private var showGrocerySheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select a Category")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.leading)

                Spacer()

                Button(Constants.cancel) {
                    showCategorySelection = false
                }
                .foregroundColor(.blue)
                .padding(.trailing)
            }
            .padding(.bottom, 8)

            Button(action: {
                showGrocerySheet = true
            }) {
                HStack {
                    Text("🍎")
                        .font(.system(size: 24))
                        .padding(.leading, 0)
                        .padding(.trailing, 5)
                    Text(Constants.groceryAndFood)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Constants.shoppingCategoryColors[Constants.groceryAndFood] ?? .gray)
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .sheet(isPresented: $showGrocerySheet, onDismiss: {
            }) {
                GroceryCategorySheet(selectedCategoryEmoji: $selectedCategoryEmoji,
                                     selectedCategory: $selectedCategory,
                                     showGrocerySheet: $showGrocerySheet,
                                     dismissCategorySheet: {
                    if !selectedCategory.isEmpty {
                        selectedCategoryFromGroceryFood = true
                        showCategorySelection = false
                    }
                })
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Constants.departments, id: \.self) { department in
                        DepartmentButton(department: department)
                    }
                }
                .padding(.horizontal)
            }

            if !isCustomCategory {
                Button(action: { isCustomCategory = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.blue)
                        Text("Custom Category")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }

            if isCustomCategory {
                VStack {
                    TextField("Enter Custom Category", text: $customCategory)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    Button(Constants.save) {
                        if !customCategory.isEmpty {
                            selectedCategory = customCategory
                            
                            showCategorySelection = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(customCategory.isEmpty)
                    .padding(.top, 4)
                }
                .padding()
            }
        }
        .padding(.top)
        .background(Color(.systemBackground)) // ✅ Full screen bg safe
    }
    
    private func DepartmentButton(department: String) -> some View {
        Button(action: {
            selectedCategory = department
            
            // Set emoji directly here using the same logic as in CategoryIcon
            if let symbol = Constants.groceryFoodCategoryIcons[department], UIImage(systemName: symbol) != nil {
                selectedCategoryEmoji = symbol
            } else if let emoji = Constants.groceryFoodCategoryIcons[department] ?? Constants.shoppingCategoryIcons[department] {
                selectedCategoryEmoji = emoji
            } else {
                selectedCategoryEmoji = "🛍️"  // Default emoji
            }
            
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack(spacing: 12) {
                CategoryIcon(category: department)
                    .frame(width: 30, height: 30)
                Text(department)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Constants.shoppingCategoryColors[department] ?? .gray)
            .cornerRadius(8)
        }
    }
    
    private func CategoryIcon(category: String) -> some View {
        // First check if we have a valid system image from groceryFoodCategoryIcons
        if let symbol = Constants.groceryFoodCategoryIcons[category], UIImage(systemName: symbol) != nil {
            return AnyView(
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Constants.shoppingCategoryColors[category] ?? .gray)
            )
        }
        // Then check if we have any emoji or symbol from either dictionary
        else if let emojiOrSymbol = Constants.groceryFoodCategoryIcons[category] ?? Constants.shoppingCategoryIcons[category] {
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
        }
        // Fallback to shopping bag emoji
        else {
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
//    CategorySelectionView()
//}
