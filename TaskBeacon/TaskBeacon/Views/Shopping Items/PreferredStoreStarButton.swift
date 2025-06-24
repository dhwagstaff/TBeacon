//
//  PreferredStoreStarButton.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/24/25.
//

import SwiftUI

struct PreferredStoreStarButton: View {
    let isPreferred: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isPreferred ? "star.fill" : "star")
                .foregroundColor(isPreferred ? .yellow : .gray)
        }
    }
}

//#Preview {
//    PreferredStoreStarButton()
//}
