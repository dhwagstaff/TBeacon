//
//  HelpTopicDetailView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/20/25.
//

import SwiftUI

struct HelpTopicDetailView: View {
    let topic: HelpTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title and subtitle
                Text(topic.title)
                    .font(.title2)
                    .bold()
                    .padding(.top, 8)
                if let subtitle = topic.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                // Main content
                Text(topic.content)
                    .font(.body)
                    .padding(.vertical, 4)

                // Permissions Section
                if let permissions = topic.permissions, !permissions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Permissions Needed")
                            .font(.headline)
                            .padding(.top, 8)
                        ForEach(permissions) { permission in
                            PermissionDetailView(permission: permission)
                        }
                    }
                }

                // Permission Steps (if present)
                if let steps = topic.permissionSteps, !steps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Permission Setup Steps")
                            .font(.headline)
                            .padding(.top, 8)
                        ForEach(steps) { step in
                            HStack(alignment: .top) {
                                Text("\(step.step).")
                                    .font(.body)
                                    .bold()
                                VStack(alignment: .leading) {
                                    Text(step.title)
                                        .font(.subheadline)
                                        .bold()
                                    Text(step.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Tips
                if let tips = topic.tips, !tips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tips")
                            .font(.headline)
                            .padding(.top, 8)
                        ForEach(tips, id: \.self) { tip in
                            Label(tip, systemImage: "lightbulb")
                                .foregroundColor(.yellow)
                        }
                    }
                }

                // Other sections (steps, features, benefits, etc.) as before...
            }
            .padding(.horizontal)
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

// Helper view for permission details
struct PermissionDetailView: View {
    let permission: HelpPermission

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: permission.icon)
                    .foregroundColor(permission.required ? .blue : .gray)
                Text(permission.name)
                    .font(.headline)
                if permission.required {
                    Text("Required")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                } else {
                    Text("Optional")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            Text(permission.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let details = permission.details {
                ForEach(details, id: \.self) { detail in
                    HStack(alignment: .top) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text(detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if let whyCritical = permission.whyCritical {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(whyCritical)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

//#Preview {
//    HelpTopicDetailView()
//}
