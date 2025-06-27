//
//  LoadingOverlay.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/27/25.
//

import SwiftUI

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.9)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(2.0)  // Increased from 1.5
                    .tint(.accentColor)
                    .padding()
                    .background(
                        Circle()
                            .fill(Color(.systemBackground))
                            .shadow(radius: 5)
                    )
                
                Text("Loading Stores...")
                    .font(.title2)  // Increased from headline
                    .fontWeight(.bold)  // Added bold
                    .foregroundColor(.primary)
                
                Text("Finding stores near your location")
                    .font(.headline)  // Increased from subheadline
                    .foregroundColor(.secondary)
            }
            .padding(30)  // Increased padding
            .background(
                RoundedRectangle(cornerRadius: 20)  // Increased corner radius
                    .fill(Color(.systemBackground))
                    .shadow(radius: 15)  // Increased shadow
            )
        }
        .transition(.opacity)
    }
}
#Preview {
    LoadingOverlay()
}
