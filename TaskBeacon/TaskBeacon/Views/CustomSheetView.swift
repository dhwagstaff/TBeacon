//
//  CustomSheetView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/8/25.
//

import SwiftUI

struct CustomSheetView: View {
    @Binding var showAddShoppingItem: Bool
    @Binding var showAddTodoItem: Bool
    @Binding var selectedShoppingItem: ShoppingItemEntity?
    @Binding var selectedToDoItem: ToDoItemEntity?
    @Binding var navigateToEditableList: Bool
    @Binding var isShowingAnySheet: Bool

    @EnvironmentObject var dataUpdateManager: DataUpdateManager
    @EnvironmentObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject var todoListViewModel: ToDoListViewModel
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        ZStack {
            if showAddShoppingItem {
                AddEditShoppingItemView(
                    navigateToEditableList: $navigateToEditableList,
                    showAddShoppingItem: $showAddShoppingItem,
                    isShowingAnySheet: $isShowingAnySheet,
                    isEditingExistingItem: false
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground)) // ✅ adaptive
                .cornerRadius(16)
                .shadow(radius: 10)
                .transition(.move(edge: .bottom))
                .onDisappear { refreshShoppingData() }
            }

            if showAddTodoItem {
                AddEditToDoItemView(
                    toDoItem: selectedToDoItem,
                    showAddTodoItem: $showAddTodoItem,
                    isShowingAnySheet: $isShowingAnySheet,
                    navigateToEditableList: $navigateToEditableList,
                    isEditingExistingItem: selectedToDoItem != nil
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground)) // ✅ adaptive
                .cornerRadius(16)
                .shadow(radius: 10)
                .transition(.move(edge: .bottom))
                .onDisappear { refreshToDoData() }
            }

            if let shoppingItem = selectedShoppingItem {
                AddEditShoppingItemView(
                    navigateToEditableList: .constant(false),
                    showAddShoppingItem: $showAddShoppingItem,
                    isShowingAnySheet: $isShowingAnySheet,
                    isEditingExistingItem: true,
                    shoppingItem: shoppingItem
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground)) // ✅ adaptive
                .cornerRadius(16)
                .shadow(radius: 10)
                .transition(.move(edge: .bottom))
                .onDisappear {
                    selectedShoppingItem = nil
                    isShowingAnySheet = false
                    refreshShoppingData()
                }
            }

            if let toDoItem = selectedToDoItem {
                AddEditToDoItemView(
                    toDoItem: toDoItem,
                    showAddTodoItem: $showAddTodoItem,
                    isShowingAnySheet: $isShowingAnySheet,
                    navigateToEditableList: .constant(false),
                    isEditingExistingItem: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground)) // ✅ adaptive
                .cornerRadius(16)
                .shadow(radius: 10)
                .transition(.move(edge: .bottom))
                .onDisappear {
                    selectedToDoItem = nil
                    isShowingAnySheet = false
                    refreshToDoData()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .background(
            showAddShoppingItem || showAddTodoItem || selectedShoppingItem != nil || selectedToDoItem != nil
            ? Color.black.opacity(0.3)
            : Color.clear
        )
    }

    private func refreshShoppingData() {
        // First, post a notification to force immediate refresh
        NotificationCenter.default.post(name: NSNotification.Name("ForceUIRefreshAfterSave"), object: nil)
        
        // Force a direct fetch to ensure we have the latest data
        shoppingListViewModel.fetchShoppingItemsOnce()
        
        // Update groupings after fresh fetch
        shoppingListViewModel.updateGroupedItemsByStoreAndCategory(updateExists: true)
        
        // Set flag for parent view to know refresh is needed
        dataUpdateManager.needsRefresh = true
        navigateToEditableList = true
        
        // Post specific notification for UI to refresh
        NotificationCenter.default.post(name: ShoppingNotification.forceUIRefresh.name, object: nil)
        
        // Log item count to verify refresh
        print("📋 Sheet dismissed - Shopping items count: \(shoppingListViewModel.shoppingItems.count)")
        
        resetState()
    }

    private func refreshToDoData() {
        todoListViewModel.updateGroupedToDoItems(updateExists: true)
        dataUpdateManager.needsRefresh = true
        navigateToEditableList = true
        resetState()
    }

    private func resetState() {
        showAddShoppingItem = false
        showAddTodoItem = false
        isShowingAnySheet = false
    }
}

//#Preview {
//    CustomSheetView()
//}
