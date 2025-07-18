//
//  ErrorAlertView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 7/18/25.
//

import SwiftUI

struct ErrorAlertView: View {
    @ObservedObject var errorManager = ErrorAlertManager.shared
    
    var body: some View {
        EmptyView()
            .alert(errorManager.errorTitle, isPresented: $errorManager.showError) {
                Button(errorManager.dismissButtonText) {
                    errorManager.dismiss()
                }
            } message: {
                Text(errorManager.errorMessage)
            }
    }
}

#Preview {
    ErrorAlertView()
}
