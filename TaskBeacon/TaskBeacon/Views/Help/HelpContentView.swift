//
//  HelpContentView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/20/25.
//

import SwiftUI

struct HelpContentView: View {
    let helpGuide: HelpGuide
    @Binding var searchText: String

    var filteredSections: [HelpSection] {
        if searchText.isEmpty {
            return helpGuide.sections
        } else {
            return helpGuide.sections.filter { section in
                section.title.localizedCaseInsensitiveContains(searchText) ||
                section.topics.contains(where: { $0.title.localizedCaseInsensitiveContains(searchText) || ($0.content.localizedCaseInsensitiveContains(searchText)) })
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            VStack(spacing: 16) {
                Text("Help Guide")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("Search Help", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Scrollable list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredSections) { section in
                        NavigationLink(destination: HelpSectionDetailView(section: section)) {
                            HStack {
                                Image(systemName: section.icon)
                                    .foregroundColor(Color(section.color))
                                    .frame(width: 24, height: 24)
                                
                                Text(section.title)
                                    .foregroundColor(.primary)
                                    .font(.body)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                            .padding(.leading, 56) // Align with text
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
//    var body: some View {
//        List {
//            Text("Help Guide")
//                .foregroundColor(.primary)
//                .font(.title)
//
//            if #available(iOS 15.0, *) {
//                Section {
//                    TextField("Search Help", text: $searchText)
//                        .textFieldStyle(.roundedBorder)
//                }
//            }
//            
//            ForEach(filteredSections) { section in
//                NavigationLink(destination: HelpSectionDetailView(section: section)) {
//                    HStack {
//                        Image(systemName: section.icon)
//                            .foregroundColor(Color(section.color))
//                            .frame(width: 24, height: 24)
//                        
//                        Text(section.title)
//                            .foregroundColor(.primary)
//                            .font(.body)
//                        
//                        Spacer()
//                        
////                        Image(systemName: "chevron.right")
////                            .foregroundColor(.secondary)
////                            .font(.caption)
//                    }
//                }
//                .listRowBackground(Color(.systemBackground))
//            }
//        }
//        .listStyle(.insetGrouped)
//        .background(Color(.systemBackground))
//    }
}

//#Preview {
//    HelpContentView()
//}
