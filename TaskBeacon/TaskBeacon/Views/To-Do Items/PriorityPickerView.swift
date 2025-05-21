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
                      //  HStack(spacing: 4) {
//                            Circle()
//                                .fill(priorityColor(for: priority.int16Value, colorScheme: colorScheme))
//                                .frame(width: 12, height: 12)
                            Text(priority.title)
                                .font(.subheadline)
                                .foregroundColor(selectedPriority == priority.int16Value ? .white : .primary)
                      //  }
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
    
//    func priorityColor(for priority: Int16) -> Color {
//        switch priority {
//        case 1: return colorScheme == .dark ? .red.opacity(0.9) : .red
//        case 2: return colorScheme == .dark ? .orange.opacity(0.9) : .orange
//        case 3: return colorScheme == .dark ? .green.opacity(0.9) : .green
//        default: return colorScheme == .dark ? .gray.opacity(0.7) : .gray
//        }
//    }
}

//struct PriorityPickerView: View {
//    @Binding var selectedPriority: Int16
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            Text("Priority")
//                .font(.headline)
//                .foregroundColor(.primary)
//
//            Picker("Priority", selection: Binding(
//                get: { Priority.from(intValue: selectedPriority) },
//                set: { selectedPriority = $0.int16Value }
//            )) {
//                ForEach(Priority.allCases) { priority in
//                    Text(priority.title).tag(priority)
//                }
//            }
//            .pickerStyle(SegmentedPickerStyle())
//        }
//        .padding()
//        .background(Color(.systemBackground))
//    }
//}

//struct PriorityPickerView: View {
//    @Binding var selectedPriority: Int16
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            Text("Priority").font(.headline)
//
//            Picker("Priority", selection: Binding(
//                get: { Priority.from(intValue: selectedPriority) },
//                set: { selectedPriority = $0.int16Value }
//            )) {
//                ForEach(Priority.allCases) { priority in
//                    Text(priority.title).tag(priority)
//                }
//            }
//            .pickerStyle(SegmentedPickerStyle())
//        }
//        .padding()
//    }
//}

struct PriorityPickerView_Previews: PreviewProvider {
    static var previews: some View {
        PriorityPickerView(selectedPriority: .constant(1))
    }
}
