//
//  HelpSectionDetailView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/20/25.
//

import SwiftUI

struct HelpSectionDetailView: View {
    let section: HelpSection

    var body: some View {
        List {
            ForEach(section.topics) { topic in
                NavigationLink(destination: HelpTopicDetailView(topic: topic)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topic.title)
                            .font(.headline)
                        if let subtitle = topic.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(section.title)
    }
}

//#Preview {
//    HelpSectionDetailView()
//}
