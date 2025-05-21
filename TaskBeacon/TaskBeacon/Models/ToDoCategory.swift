//
//  ToDoCategory.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/18/25.
//

import Foundation
import SwiftUI

struct ToDoCategory {
    let name: String
    let icon: String // SF Symbol name or emoji
    let color: Color
    let subcategories: [String]
}

// ✅ Example Data
let toDoCategories: [ToDoCategory] = [
    ToDoCategory(name: "Errands & Travel", icon: "car.fill", color: .blue, subcategories: ["Transportation", "Deliveries & Returns", "Appointments"]),
    ToDoCategory(name: "Home Chores", icon: "house.fill", color: .green, subcategories: ["Cleaning", "Maintenance", "Organization"]),
    ToDoCategory(name: "Medical & Health", icon: "heart.fill", color: .red, subcategories: ["Doctor Visits", "Medication", "Fitness Goals"]),
    ToDoCategory(name: "Finance & Bills", icon: "creditcard.fill", color: .purple, subcategories: ["Payments", "Budgeting", "Investments"]),
    ToDoCategory(name: "Work & Productivity", icon: "briefcase.fill", color: .orange, subcategories: ["Meetings", "Projects", "Deadlines"]),
    ToDoCategory(name: "Hobbies & Leisure", icon: "paintbrush.fill", color: .yellow, subcategories: ["Reading", "Music", "Outdoor Activities"]),
    ToDoCategory(name: "Education & Learning", icon: "book.fill", color: .indigo, subcategories: ["Courses", "Research", "Skills"]),
    ToDoCategory(name: "Social & Events", icon: "person.3.fill", color: .teal, subcategories: ["Birthdays", "Meetups", "Celebrations"]),
    ToDoCategory(name: "Personal Growth", icon: "star.fill", color: .pink, subcategories: ["Journaling", "Meditation", "Self-care"])
]

