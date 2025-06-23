//
//  ShoppingItemRow.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/12/25.
//

import SwiftUI

struct ShoppingItemRow: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var viewModel: ShoppingListViewModel

    @ObservedObject var item: ShoppingItemEntity

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ZStack {
                    Button(action: {
                        item.isCompleted.toggle()
                        
                        viewModel.completeShoppingItem(item, completed: item.isCompleted)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                self.viewModel.refreshTrigger = UUID()
                            }
                        }
                    }) {
                        Image(systemName: item.isCompleted ? ImageSymbolNames.checkmarkCircleFill : ImageSymbolNames.circle)
                            .foregroundColor(item.isCompleted ? .green : colorScheme == .dark ? .gray.opacity(0.7) : .gray)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .contentShape(Rectangle())
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        if let imageData = item.productImage, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .cornerRadius(6)
                                .shadow(color: colorScheme == .dark ? .black.opacity(0.3) : .gray.opacity(0.2), radius: 4)
                        } else {
                            Text(item.emoji ?? "🛒")
                                .font(.title2)
                        }
                        
                        Text(item.name ?? "Unknown")
                            .font(.headline)
                            .strikethrough(item.isCompleted, color: colorScheme == .dark ? .gray.opacity(0.7) : .gray)
                            .foregroundColor(item.isCompleted ? .gray : .primary)
                            .foregroundColor(item.isCompleted ?
                                             (colorScheme == .dark ? .gray.opacity(0.7) : .gray) :
                                    .primary)
                    }
                    
                    if let storeName = item.storeName, !storeName.isEmpty {
                        // Only show store name if this item is in the "Other" or unassigned group
                    } else {
                        Text("⚠️ No store assigned")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .padding(4)
                            .background(
                                colorScheme == .dark ?
                                Color.orange.opacity(0.15) :
                                    Color.orange.opacity(0.1)
                            )
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                // Add subtle "more options" indicator for unassigned items
                HStack {
                    Spacer()
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 50, height: 50)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(0.6)
                }
                .padding(.trailing, 20)
            }
            .padding(.vertical, 4)
        }
        .background(
            colorScheme == .dark ?
                Color(.systemGray6) :
                Color(.systemBackground)
        )
    }
}

func makeMockShoppingItem() -> ShoppingItemEntity {
    let context = PersistenceController.shared.container.viewContext
    let item = ShoppingItemEntity(context: context)
    item.uid = UUID().uuidString
    item.name = "Organic Bananas"
    item.category = "Grocery -> Fresh Produce"
    item.storeName = "Whole Foods Market"
    item.price = 2.99
    item.isCompleted = false
    item.expirationDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())
    return item
}

#Preview {
    ShoppingItemRow(item: makeMockShoppingItem())
}


