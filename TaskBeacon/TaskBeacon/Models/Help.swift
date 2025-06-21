//
//  HelpPlan.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/20/25.
//

import Foundation

// MARK: - Help Guide Models
struct HelpPlan: Codable, Identifiable {
    var id: String { name }
    let name: String
    let features: [String]
    let limitations: [String]?
    let benefits: [String]?
}

struct HelpGuide: Codable {
    let appName: String
    let version: String
    let sections: [HelpSection]
}

struct HelpSection: Codable, Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: String
    let topics: [HelpTopic]
}

struct HelpTopic: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let content: String
    let image: String?
    let tips: [String]?
    let permissions: [HelpPermission]?
    let permissionSteps: [PermissionStep]?
    let methods: [HelpMethod]?
    let steps: [String]?
    let features: [String]?
    let fields: [HelpField]?
    let priorities: [HelpPriority]?
    let benefits: [String]?
    let howItWorks: [String]?
    let settings: [String]?
    let searchMethods: [String]?
    let information: [String]?
    let plans: [HelpPlan]?
    let howToEarn: [String]?
    let options: [String]?
}

struct HelpPermission: Codable, Identifiable {
    var id: String { name }
    let name: String
    let description: String
    let icon: String
    let required: Bool
    let details: [String]?
    let whyCritical: String?
}

struct PermissionStep: Codable, Identifiable {
    var id: Int { step }
    let step: Int
    let title: String
    let description: String
}

struct HelpMethod: Codable, Identifiable {
    var id: String { title }
    let title: String
    let description: String
    let icon: String
}

struct HelpField: Codable, Identifiable {
    var id: String { name }
    let name: String
    let description: String
    let required: Bool
}

struct HelpPriority: Codable, Identifiable {
    var id: String { level }
    let level: String
    let color: String
    let description: String
}
