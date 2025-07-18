//
//  PriorityPickerView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 2/21/25.
//

import SwiftUI

enum Priority: Int, CaseIterable, Identifiable {
    case high = 1
    case medium = 2
    case low = 3
    
    var id: Int { self.rawValue }
    
    var title: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
    
    // ✅ Convert from Int16 (for Core Data)
    static func from(intValue: Int16) -> Priority {
        return Priority(rawValue: Int(intValue)) ?? .medium
    }
    
    // ✅ Convert to Int16 (for Core Data)
    var int16Value: Int16 {
        return Int16(self.rawValue)
    }
}

struct PriorityPickerView: View {
    @Binding var selectedPriority: Int16
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Priority")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 0) {
                ForEach(Priority.allCases) { priority in
                    Button(action: {
                        selectedPriority = priority.int16Value
                    }) {
                        Text(priority.title)
                            .font(.subheadline)
                            .foregroundColor(selectedPriority == priority.int16Value ? .white : .primary)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedPriority == priority.int16Value ?
                                priorityColor(for: priority.int16Value, colorScheme: colorScheme) :
                                    Color(.systemGray6)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct PriorityPickerView_Previews: PreviewProvider {
    static var previews: some View {
        PriorityPickerView(selectedPriority: .constant(1))
    }
}
