//
//  FirstTimeLoadView.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/5/25.
//

import MapKit
import SwiftUI

struct EmptyStateView: View {
    @AppStorage("selectedSegment") private var selectedSegment: String = "Shopping"

    @EnvironmentObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject var todoListViewModel: ToDoListViewModel
    @EnvironmentObject var locationManager: LocationManager

    @State private var selectedStore: String = ""
    @State private var nearbyStores: [StoreOption] = []
    @State private var isShowingAnySheet = false
    @State private var showAddShoppingItem = false
    @State private var showAddTodoItem = false
    @State private var navigateToEditableList = false
    @State private var scannedItem: ShoppingItemEntity?
    @State private var mkStores: [MKMapItem] = []
    @State private var currentIndex = 0
    
    let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    let icons = [
        (systemName: "cart", title: "Shopping List", color: Color(hex: "FFD300")),
        (systemName: "checklist", title: "To-Do List", color: Color(hex: "005D5D")),
        (systemName: "mappin.and.ellipse", title: "Location-Based Reminders", color: Color(hex: "1240AB"))
    ]

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let iconSize = screenHeight * 0.05
            let verticalSpacing = screenHeight * 0.02
            let suggestedItemsVerticalSpacing = screenHeight * 0.001

            NavigationStack {
                VStack(spacing: verticalSpacing + 15) {
                    Spacer(minLength: screenHeight * 0.10)
                    
                    Text("Echolist")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "FFD300"), Color(hex: "005D5D").opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(maxWidth: .infinity)
                    
                    VStack {
                        // Animated icon and text
                        VStack(spacing: 20) {
                            Image(systemName: icons[currentIndex].systemName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(icons[currentIndex].color)
                                .transition(.scale.combined(with: .opacity))
                            
                            Text(icons[currentIndex].title)
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .transition(.opacity)
                        }
                        .animation(.easeInOut, value: currentIndex)
                    }
                    .onReceive(timer) { _ in
                        withAnimation {
                            currentIndex = (currentIndex + 1) % icons.count
                        }
                    }

                    VStack {
                        Text("Your lists are empty!")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.top, 10)

                        Text("Start adding items and get location-based reminders.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .minimumScaleFactor(0.8)
                            .padding([.bottom], 10)

                        VStack(spacing: verticalSpacing) {
                            Button(action: {
                                selectedSegment = "Shopping"
                                showAddShoppingItem = true
                            }) {
                                buttonLabel(icon: ImageSymbolNames.cartFill, title: "Create Your First Shopping List")
                            }
                            .background(Color(hex: "FFD300"))
                            .cornerRadius(10)
                            .padding([.leading, .trailing], 10)

                            Button(action: {
                                selectedSegment = "To-Do"
                                showAddTodoItem = true
                            }) {
                                buttonLabel(icon: "list.bullet", title: "Create Your First To-Do List")
                            }
                            .background(Color(hex: "005D5D"))
                            .cornerRadius(10)
                            .padding([.leading, .trailing, .bottom], 10)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 0)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal, 0)

                    VStack(alignment: .leading, spacing: suggestedItemsVerticalSpacing) {
                        Text("Example Items")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(alignment: .center)
                            .padding(.top, 10)

                        ForEach(["Milk", "Bread", "Visit Mom", "Pick up dry cleaning"], id: \.self) { item in
                            HStack {
                                Image(systemName: "checkmark.circle").foregroundColor(Color(hex: "FF7400"))
                                
                                Text(item).foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: item == "Milk" || item == "Bread" ? ImageSymbolNames.cartFill : "list.bullet")
                                    .foregroundColor(item == "Milk" || item == "Bread" ? Color(hex: "FFD300") : Color(hex: "005D5D"))
                            }
                            .padding(.bottom, 20)
                            .padding(.horizontal, 40)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                    )

                    Spacer(minLength: screenHeight * 0.08)
                }
                .padding()
                .background(Color(.systemBackground))
                .onAppear {
                    if shoppingListViewModel.emojiMap.isEmpty {
                        shoppingListViewModel.emojiMap = shoppingListViewModel.loadEmojiMap()
                    }
                }
                .fullScreenCover(isPresented: $navigateToEditableList) {
                    EditableListView()
                        .environmentObject(LocationManager.shared)
                        .environmentObject(shoppingListViewModel)
                        .environmentObject(todoListViewModel)
                }
                .fullScreenCover(isPresented: $showAddShoppingItem, onDismiss: {
                    navigateToEditableList = true
                }) {
                    AddEditShoppingItemView(
                        navigateToEditableList: $navigateToEditableList,
                        showAddShoppingItem: $showAddShoppingItem,
                        isShowingAnySheet: $isShowingAnySheet,
                        isEditingExistingItem: false,
                        shoppingItem: scannedItem
                    )
                }
                .fullScreenCover(isPresented: $showAddTodoItem, onDismiss: {
                    navigateToEditableList = true
                }) {
                    AddEditToDoItemView(toDoItem: nil,
                                        showAddTodoItem: $showAddTodoItem,
                                        isShowingAnySheet: $isShowingAnySheet,
                                        navigateToEditableList: $navigateToEditableList,
                                        isEditingExistingItem: false)
                }
            }
        }
    }

    private func iconBlock(systemName: String, title: String, color: Color, size: CGFloat) -> some View {
        VStack {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(color)
                .opacity(0.8)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }

    private func buttonLabel(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
              //  .minimumScaleFactor(1.0)
        }
        .padding()
    }
}

//struct EmptyStateView_Previews: PreviewProvider {
//    static var previews: some View {
//        EmptyStateView()
//            .environmentObject(ShoppingListViewModel(context: PersistenceController.shared.container.viewContext))
//            .previewDevice(PreviewDevice(rawValue: "iPhone 11 Pro Max"))
//            .previewDisplayName("iPhone 11 Pro Max")
//
//        EmptyStateView()
//            .environmentObject(ShoppingListViewModel(context: PersistenceController.shared.container.viewContext))
//            .previewDevice(PreviewDevice(rawValue: "iPhone 13 mini"))
//            .previewDisplayName("iPhone 13 mini")
//
//    }
//}
