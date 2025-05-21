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
        let priority = Priority.from(intValue: item.priority)

        HStack(alignment: .top, spacing: 12) {
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
            .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.task ?? "Untitled")
                    .font(.headline)
                    .strikethrough(item.isCompleted, color: colorScheme == .dark ? .gray.opacity(0.7) : .secondary)
                    .foregroundColor(item.isCompleted ? (colorScheme == .dark ? .gray.opacity(0.7) : .secondary) : .primary)
                    .lineLimit(2)
                
                VStack(spacing: 5) {
                    if showCategory, let category = item.category, !category.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "tag")
                                .imageScale(.small)
                            Text(category)
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let dueDate = item.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .imageScale(.small)
                            Text(formatDate(dueDate))
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let location = item.addressOrLocationName, !location.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "location")
                                .imageScale(.small)
                            Text(location)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
            
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
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
        .cornerRadius(8)
        .padding(.top, 8)
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

// MARK: - Function Wrapper (if you want to keep the function style)

@ViewBuilder
func todoItemRow(item: ToDoItemEntity, showCategory: Bool = false, onDelete: (() -> Void)? = nil) -> some View {
    ToDoItemRow(item: item, showCategory: showCategory, onDelete: onDelete)
}
