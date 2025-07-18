//
//  ToDoCategorySelectionView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/18/25.
//

import CoreData
import SwiftUI

struct ToDoCategorySelectionView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel: ToDoListViewModel
    
    @Binding var selectedCategory: String
    
    @State private var showingAddCustomCategory = false
    @State private var newCustomCategory = ""
    @State private var isCustomAlertCancelled = false
    @State private var showingEditCustomCategory = false
    @State private var editingCategory = ""

    init(selectedCategory: Binding<String>, context: NSManagedObjectContext) {
        self._selectedCategory = selectedCategory
        self._viewModel = StateObject(wrappedValue: ToDoListViewModel(context: context))
    }

    var body: some View {
        NavigationView {
            List {
                // Custom Categories Section
                Section(header: Text("My Categories").foregroundColor(.primary)) {
                    // Add Custom Category Button
                    Button(action: {
                        newCustomCategory = Constants.emptyString
                        showingAddCustomCategory = true
                        isCustomAlertCancelled = false
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add Custom Category")
                                .foregroundColor(.blue)
                        }
                        .padding(5)
                    }
                    
                    // Existing Custom Categories
                    if let customCategories = viewModel.allCategories["Custom"], !customCategories.isEmpty {
                        ForEach(customCategories, id: \.self) { category in
                            customCategoryRow(category)
                        }
                        .onDelete { indexSet in
                            // Get the categories to delete
                            let categoriesToDelete = indexSet.map { customCategories[$0] }
                            // Delete each category
                            for category in categoriesToDelete {
                                viewModel.removeCustomCategory(category)
                            }
                        }
                    }
                }
                
                // Standard Categories
                ForEach(viewModel.allCategories.keys.filter { $0 != "Custom" }.sorted(), id: \.self) { categoryGroup in
                    Section(header: Text(categoryGroup).foregroundColor(.primary)) {
                        ForEach(viewModel.allCategories[categoryGroup] ?? [], id: \.self) { subcategory in
                            categoryRow(subcategory)
                        }
                    }
                }
            }
            .navigationTitle(Constants.selectCategory)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
            .background(Color(.systemBackground))
            .alert("Add Custom Category", isPresented: $showingAddCustomCategory) {
                TextField("Category Name", text: $newCustomCategory)
                Button(Constants.cancel, role: .cancel) {
                    newCustomCategory = ""
                    isCustomAlertCancelled = true
                }
                Button("Add") {
                    if !newCustomCategory.isEmpty {
                        viewModel.addCustomCategory(newCustomCategory)
                        selectedCategory = newCustomCategory
                        newCustomCategory = ""
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .disabled(newCustomCategory.isEmpty)
            } message: {
                Text("Enter a name for your custom category")
            }
            .alert("Edit Custom Category", isPresented: $showingEditCustomCategory) {
                TextField("Category Name", text: $newCustomCategory)
                Button(Constants.cancel, role: .cancel) {
                    newCustomCategory = ""
                }
                Button("Save") {
                    if !newCustomCategory.isEmpty {
                        viewModel.updateCustomCategory(from: editingCategory, to: newCustomCategory)
                        if selectedCategory == editingCategory {
                            selectedCategory = newCustomCategory
                        }
                        newCustomCategory = ""
                    }
                }
                .disabled(newCustomCategory.isEmpty)
            } message: {
                Text("Edit your custom category name")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ToDoNotification.todoCategoriesUpdated.name)) { _ in
            viewModel.objectWillChange.send()
        }
    }
    
    private func customCategoryRow(_ category: String) -> some View {
        HStack {
            if !category.isEmpty {
                Image(systemName: Constants.toDoCategoryIcons[category] ?? "tag.fill")
                    .foregroundColor(Constants.toDoCategoryColors[category] ?? .gray)
                Text(category)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if selectedCategory == category {
                    Image(systemName: ImageSymbolNames.checkmarkCircleFill)
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: ImageSymbolNames.circle)
                        .foregroundColor(.gray)
                }

            }
        }
        .padding(5)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedCategory = category
            presentationMode.wrappedValue.dismiss()
        }
        .contextMenu {
            Button(action: {
                editingCategory = category
                newCustomCategory = category
                showingEditCustomCategory = true
            }) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: {
                viewModel.removeCustomCategory(category)
                if selectedCategory == category {
                    selectedCategory = "All"
                }
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func categoryRow(_ category: String) -> some View {
        Button(action: {
            selectedCategory = category
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Image(systemName: Constants.toDoCategoryIcons[category] ?? "tag.fill")
                    .foregroundColor(Constants.toDoCategoryColors[category] ?? .gray)
                
                Text(category)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if selectedCategory == category {
                    Image(systemName: ImageSymbolNames.checkmarkCircleFill)
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: ImageSymbolNames.circle)
                        .foregroundColor(.gray)
                }
            }
            .padding(5)
        }
    }
}

//#Preview {
//    ToDoCategorySelectionView(selectedCategory: .constant("Appointment"))
//}
