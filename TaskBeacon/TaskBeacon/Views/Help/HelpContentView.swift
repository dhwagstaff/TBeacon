//
//  HelpContentView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/20/25.
//

import SwiftUI

struct HelpContentView: View {
    @Binding var searchText: String
    
    let helpGuide: HelpGuide

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
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search Help", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Scrollable list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredSections) { section in
                        NavigationLink(destination: HelpSectionDetailView(section: section)) {
                            HStack(spacing: 16) {
                                // Enhanced icon with background
                                ZStack {
                                    Circle()
                                        .fill(Color(section.color).opacity(0.15))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: section.icon)
                                        .foregroundColor(Color(section.color))
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(section.title)
                                        .foregroundColor(.primary)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    
                                    Text("\(section.topics.count) topics")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                
                                Spacer()
                                
                                // Enhanced chevron
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.trailing, 4)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray5), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            
//            ScrollView {
//                LazyVStack(spacing: 0) {
//                    ForEach(filteredSections) { section in
//                        NavigationLink(destination: HelpSectionDetailView(section: section)) {
//                            HStack {
//                                Image(systemName: section.icon)
//                                    .foregroundColor(Color(section.color))
//                                    .frame(width: 24, height: 24)
//                                
//                                Text(section.title)
//                                    .foregroundColor(.primary)
//                                    .font(.headline)
//                                    .fontWeight(.bold)
//                                
//                                Spacer()
//                                
//                                Image(systemName: "chevron.right")
//                                    .foregroundColor(.secondary)
//                                    .font(.caption)
//                            }
//                            .padding()
//                            .background(Color(.systemBackground))
//                        }
//                        .buttonStyle(PlainButtonStyle())
//                        
//                        Divider()
//                            .padding(.leading, 56) // Align with text
//                    }
//                }
//            }
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
