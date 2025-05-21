//
//  Category.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/7/25.
//

import Foundation

struct Category: Identifiable, Hashable {
    let id = UUID()
    let name: String
}
