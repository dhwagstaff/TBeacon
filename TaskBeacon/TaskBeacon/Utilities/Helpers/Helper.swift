//
//  Helper.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 4/23/25.
//

import Foundation
import MapKit
import SwiftUI

func priorityColor(for priority: Int16, colorScheme: ColorScheme) -> Color {
    switch priority {
    case 1: return colorScheme == .dark ? Color(hex: "FF7400").opacity(0.9) : Color(hex: "FF7400")
    case 2: return colorScheme == .dark ? Color(hex: "005D5D").opacity(0.9) : Color(hex: "005D5D")
    case 3: return colorScheme == .dark ? Color(hex: "FFD300").opacity(0.9) : Color(hex: "FFD300")
    default: return colorScheme == .dark ? .gray.opacity(0.7) : .gray
    }
}

func getCategoryIcon(for category: String) -> String {
    switch category {
    case "Grocery & Food":
        return ImageSymbolNames.cartFill
    case "General Merchandise":
        return "bag.fill"
    case "Clothing & Apparel":
        return "tshirt.fill"
    case "Home Improvement":
        return "hammer.fill"
    case "Electronics":
        return "desktopcomputer"
    case "Health & Beauty":
        return "cross.fill"
    case "Specialty Stores":
        return "star.fill"
    default:
        return "building.2.fill"
    }
}
