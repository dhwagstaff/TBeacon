//
//  CustomToolbarView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/8/25.
//

import SwiftUI

struct CustomToolbarView: View {
    @Binding var isScanning: Bool
    @Binding var showSettings: Bool
    @Binding var showAddShoppingItem: Bool
    @Binding var showAddTodoItem: Bool
    @Binding var selectedSegment: String

    var body: some View {
        HStack {
            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
                    .foregroundColor(.primary) // ✅ Adapts to light/dark
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            VStack(spacing: 8) {
                Button(action: { isScanning.toggle() }) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 22))
                        .foregroundColor(.primary) // ✅ Adapts
                }

                Menu {
                    Button {
                        showAddShoppingItem = true
                        selectedSegment = "Shopping"
                    } label: {
                        Label("Shopping Item", systemImage: ImageSymbolNames.cartFill)
                    }

                    Button {
                        showAddTodoItem = true
                        selectedSegment = "To-Do"
                    } label: {
                        Label("To-Do Item", systemImage: "checklist")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                        .foregroundColor(.primary) // ✅ Keeps icon readable
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    CustomToolbarView(isScanning: .constant(true), showSettings: .constant(true), showAddShoppingItem: .constant(true), showAddTodoItem: .constant(true), selectedSegment: .constant("Shopping"))
}
