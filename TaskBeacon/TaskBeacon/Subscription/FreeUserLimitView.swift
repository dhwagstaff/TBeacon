//
//  FreeUserLimitView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 4/30/25.
//

import SwiftUI

struct FreeUserLimitView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var showSubscriptionSheet: Bool
    
    var body: some View {
        RoundedSectionBackground(
            backgroundColor: colorScheme == .dark ?
                Color(.systemGray6) :
                Color(.systemBackground),
            title: "Free Version Limit",
            iconName: "exclamationmark.triangle.fill"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("🚫 Free users can only add up to 5 items total (shopping and to-do items combined).")
                    .foregroundColor(.red)
                    .font(.subheadline)
                
                Text("Upgrade to Premium for unlimited items.")
                    .font(.footnote)
                    .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                
                Button(action: { showSubscriptionSheet = true }) {
                    HStack {
                        Spacer()
                        Text("Go Premium")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                        Spacer()
                    }
                    .background(
                        colorScheme == .dark ?
                            Color.accentColor.opacity(0.8) :
                            Color.accentColor
                    )
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }
}

//#Preview {
//    FreeUserLimitView()
//}
