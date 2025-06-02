//
//  ToDoItemRow.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/12/25.
//

import SwiftUI
import CoreData

struct ToDoItemRow: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var viewModel: ToDoListViewModel
    
    @ObservedObject var item: ToDoItemEntity
    
    var showCategory: Bool = true
    var onDelete: (() -> Void)?
    
    var body: some View {
        VStack {
            let priority = Priority.from(intValue: item.priority)
            
            HStack(alignment: .top) {
                Button(action: {
                    item.isCompleted.toggle()
                    
                    viewModel.completeToDoItem(item, completed: item.isCompleted)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            self.viewModel.refreshTrigger = UUID()
                        }
                    }
                }) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(item.isCompleted ? .green : (colorScheme == .dark ? .gray.opacity(0.7) : .secondary))
                        .imageScale(.large)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(item.task ?? "Untitled")
                    .font(.headline)
                    .strikethrough(item.isCompleted, color: colorScheme == .dark ? .gray.opacity(0.7) : .secondary)
                    .foregroundColor(item.isCompleted ? (colorScheme == .dark ? .gray.opacity(0.7) : .secondary) : .primary)
                    .lineLimit(2)
                    .padding(.top, 1.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 30)
            
            // Details section
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    if showCategory, let category = item.category, !category.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "tag")
                                .imageScale(.small)
                            Text(category)
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(priority.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(priorityColor(for: item.priority, colorScheme: colorScheme))
                        .padding(6)
                        .background(
                            priorityColor(for: item.priority, colorScheme: colorScheme)
                                .opacity(colorScheme == .dark ? 0.3 : 0.2)
                        )
                        .cornerRadius(6)
                        .shadow(
                            color: colorScheme == .dark ?
                            Color.black.opacity(0.2) :
                                Color.gray.opacity(0.1),
                            radius: 2,
                            x: 0,
                            y: 1
                        )
                    
                }
                .frame(height: 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 30)
            }
            
            VStack {
                if let dueDate = item.dueDate {
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                            .imageScale(.small)
                        Text(formatDate(dueDate))
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 30)
                }
                
                if let location = item.addressOrLocationName, !location.isEmpty {
                    HStack(alignment: .top, spacing: 2) {
                        Image(systemName: "location")
                            .imageScale(.small)
                        Text(location)
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 30)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
        .cornerRadius(8)
        .padding(.top, -40)
        .swipeActions(edge: .trailing) {
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.task ?? "Untitled")")
        .accessibilityHint(accessibilityHint(for: item))
}
    
    // Helper functions
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy : h:mm a"
        return formatter.string(from: date)
    }
    
    func accessibilityHint(for item: ToDoItemEntity) -> String {
        var hints: [String] = []
        if let category = item.category, !category.isEmpty {
            hints.append("Category: \(category)")
        }
        if let dueDate = item.dueDate {
            hints.append("Due: \(formatDate(dueDate))")
        }
        if let location = item.addressOrLocationName, !location.isEmpty {
            hints.append("Location: \(location)")
        }
        return hints.joined(separator: ", ")
    }
}

//#Preview {
//    let context = PersistenceController.preview.container.viewContext
//    let viewModel = ToDoListViewModel(context: context)
//    
//    // Create a single mock item
//    let mockItem = ToDoItemEntity(context: context)
//    mockItem.task = "Pick up dry cleaning"
//    mockItem.priority = Int16(Priority.high.rawValue)
//    mockItem.category = "Work"
//    mockItem.dueDate = Date()
//    mockItem.addressOrLocationName = "10260 N 5200 W, Elwood, UT 84337"
//    mockItem.isCompleted = false
//    
//    return VStack(spacing: 0) {
//       // Divider()
//        
//        PriorityDisclosureGroup(
//            selectedToDoItem: .constant(nil),
//            showAddTodoItem: .constant(false),
//            isShowingAnySheet: .constant(false),
//            priority: .high,
//            isExpanded: true,
//            onToggle: { _ in },
//            items: [mockItem],
//            refreshTrigger: UUID(),
//            todoRowHeight: 120,
//            filterType: .none,
//            onDelete: { _ in }
//        )
//        .environmentObject(viewModel)
//    }
//    .padding(.horizontal)
//}
