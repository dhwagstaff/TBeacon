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
                    isShowingAnySheet: $isShowingAnySheet
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
                    navigateToEditableList: $navigateToEditableList
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
                    navigateToEditableList: .constant(false)
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

//struct CustomSheetView: View {
//    @Binding var showAddShoppingItem: Bool
//    @Binding var showAddTodoItem: Bool
//    @Binding var selectedShoppingItem: ShoppingItem?
//    @Binding var selectedToDoItem: ToDoItem?
//    @Binding var navigateToEditableList: Bool
//    @Binding var isShowingAnySheet: Bool
//    
//    @EnvironmentObject var dataUpdateManager: DataUpdateManager
//    @EnvironmentObject var shoppingListViewModel: ShoppingListViewModel
//    @EnvironmentObject var todoListViewModel: ToDoListViewModel
//    
//    var body: some View {
//        ZStack {
//            // ✅ Add Shopping Item Sheet
//            if showAddShoppingItem {
//                AddEditShoppingItemView(
//                    navigateToEditableList: $navigateToEditableList,
//                    showAddShoppingItem: $showAddShoppingItem,
//                    isShowingAnySheet: $isShowingAnySheet
//                )
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .background(Color.white)
//                .cornerRadius(16)
//                .shadow(radius: 10)
//                .transition(.move(edge: .bottom))
//                .onDisappear { refreshShoppingData() }
//            }
//            
//            // ✅ Add To-Do Item Sheet
//            if showAddTodoItem {
//                AddEditToDoItemView(toDoItem: selectedToDoItem,
//                                    showAddTodoItem: $showAddTodoItem,
//                                    isShowingAnySheet: $isShowingAnySheet,
//                                    navigateToEditableList: $navigateToEditableList)
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .background(Color.white)
//                .cornerRadius(16)
//                .shadow(radius: 10)
//                .transition(.move(edge: .bottom))
//                .onDisappear { refreshToDoData() }
//            }
//            
//            // ✅ Edit Existing Shopping Item Sheet
//            if let shoppingItem = selectedShoppingItem {
//                AddEditShoppingItemView(
//                    navigateToEditableList: .constant(false),
//                    showAddShoppingItem: $showAddShoppingItem,
//                    isShowingAnySheet: $isShowingAnySheet,
//                    shoppingItem: shoppingItem
//                )
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .background(Color.white)
//                .cornerRadius(16)
//                .shadow(radius: 10)
//                .transition(.move(edge: .bottom))
//                .onDisappear {
//                    selectedShoppingItem = nil
//                    isShowingAnySheet = false
//                    refreshShoppingData()
//                }
//            }
//            
//            // ✅ Edit Existing To-Do Item Sheet
//            if let toDoItem = selectedToDoItem {
//                AddEditToDoItemView(toDoItem: toDoItem,
//                                    showAddTodoItem: $showAddTodoItem,
//                                    isShowingAnySheet: $isShowingAnySheet,
//                                    navigateToEditableList: .constant(false))
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .background(Color.white)
//                .cornerRadius(16)
//                .shadow(radius: 10)
//                .transition(.move(edge: .bottom))
//                .onDisappear {
//                    selectedToDoItem = nil
//                    isShowingAnySheet = false
//                    refreshToDoData()
//                }
//            }
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .edgesIgnoringSafeArea(.all)
//        .background(
//            showAddShoppingItem || showAddTodoItem || selectedShoppingItem != nil || selectedToDoItem != nil
//            ? Color.black.opacity(0.3)
//            : Color.clear
//        )
//    }
//    
//    private func refreshShoppingData() {
//        shoppingListViewModel.update/*GroupedShoppingItems*/(updateExists: true)
//        dataUpdateManager.needsRefresh = true
//        navigateToEditableList = true
//        
//        resetState()
//    }
//    
//    private func refreshToDoData() {
//        todoListViewModel.updateGroupedToDoItems(updateExists: true)
//        dataUpdateManager.needsRefresh = true
//        navigateToEditableList = true
//        
//        resetState()
//    }
//    
//    private func resetState() {
//        showAddShoppingItem = false
//        showAddTodoItem = false
//        isShowingAnySheet = false  // ✅ Ensures proper dismissal
//    }
//}

//#Preview {
//    CustomSheetView()
//}
