//
//  FilterMenuView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/14/25.
//

import SwiftUI

struct FilterMenuView: View {
    @Binding var filterType: TodoFilterType
    @Binding var selectedPriority: Priority
    
    var body: some View {
        Menu {
            Button(action: {
                filterType = .none
            }) {
                HStack {
                    Text("None")
                    if filterType == .none {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Button(action: {
                filterType = .category
            }) {
                HStack {
                    Text("Category")
                    if filterType == .category {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Menu {
                Button(action: {
                    filterType = .priority
                    selectedPriority = .high
                }) {
                    HStack {
                        Text("High")
                        if filterType == .priority && selectedPriority == .high {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button(action: {
                    filterType = .priority
                    selectedPriority = .medium
                }) {
                    HStack {
                        Text("Medium")
                        if filterType == .priority && selectedPriority == .medium {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button(action: {
                    filterType = .priority
                    selectedPriority = .low
                }) {
                    HStack {
                        Text("Low")
                        if filterType == .priority && selectedPriority == .low {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Priority")
                    if filterType == .priority {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            HStack {
                Spacer()
                
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(filterType == .category ? "Filter by Category" :
                        filterType == .priority ? "Filter by \(selectedPriority.title)" :
                        "Filter Options")
            }
            .foregroundColor(.blue)
            .padding(.horizontal)
        }
    }
}

//#Preview {
//    FilterMenuView()
//}
