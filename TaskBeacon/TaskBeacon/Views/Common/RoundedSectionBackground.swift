//
//  RoundedRecBackgroundView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 4/19/25.
//

import SwiftUI

// Update the RoundedSectionBackground for more style
struct RoundedSectionBackground<Content: View>: View {
    var content: Content
    var backgroundColor: Color
    var title: String?
    var iconName: String?
    var expirationEstimate: Date? // Add optional expiration estimate
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    init(backgroundColor: Color = Color(.white).opacity(0.95),
         title: String? = nil,
         iconName: String? = nil,
         expirationEstimate: Date? = nil,
         @ViewBuilder content: () -> Content) {
        self.content = content()
        self.backgroundColor = backgroundColor
        self.title = title
        self.iconName = iconName
        self.expirationEstimate = expirationEstimate
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = title {
                HStack(spacing: 8) {
                    if let iconName = iconName {
                        Image(systemName: iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color.accentColor.opacity(0.1))
                                    .frame(width: 32, height: 32)
                            )
                    }
                    
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // Add expiration estimate if available
                    if let estimate = expirationEstimate {
                        Text("(Est: \(dateFormatter.string(from: estimate)))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Add subtle divider
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal)
            }
            
            content
                .padding(.bottom, 16)
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
