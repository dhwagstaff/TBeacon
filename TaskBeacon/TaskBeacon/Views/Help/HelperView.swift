//
//  HelperView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/20/25.
//

import Foundation
import SwiftUI

struct HelperView: View {
    @StateObject private var helpManager = HelpGuideManager.shared
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSection: HelpSection?
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            if helpManager.isLoading {
                LoadingView()
            } else if let errorMessage = helpManager.errorMessage {
                ErrorView(message: errorMessage) {
                    helpManager.loadHelpGuide()
                }
            } else if let helpGuide = helpManager.helpGuide {
                HelpContentView(searchText: $searchText, helpGuide: helpGuide)
            } else {
                EmptyView()
            }
        }
        .navigationTitle("Help & Guide")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    shareHelpGuide()
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
    
    private func shareHelpGuide() {
        // Implement sharing logic if desired
    }
}

struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
            Text("Loading help guide...")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .multilineTextAlignment(.center)
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    HelperView()
}
