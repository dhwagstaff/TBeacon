//
//  HelpGuideManager.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/20/25.
//

import Foundation

// MARK: - Help Guide Manager
class HelpGuideManager: ObservableObject {
    @Published var helpGuide: HelpGuide?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    static let shared = HelpGuideManager()
    
    private init() {
        loadHelpGuide()
    }
    
    func loadHelpGuide() {
        isLoading = true
        errorMessage = nil
        
        guard let url = Bundle.main.url(forResource: "helpGuide", withExtension: "json") else {
            ErrorAlertManager.shared.showDataError("Help guide not found")

            errorMessage = "Help guide not found"
            isLoading = false
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            helpGuide = try decoder.decode(HelpGuide.self, from: data)
            isLoading = false
        } catch {
            ErrorAlertManager.shared.showDataError("Failed to load help guide: \(error.localizedDescription)")

            errorMessage = "Failed to load help guide: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func getSection(by id: String) -> HelpSection? {
        return helpGuide?.sections.first { $0.id == id }
    }
    
    func getTopic(sectionId: String, topicId: String) -> HelpTopic? {
        guard let section = getSection(by: sectionId) else { return nil }
        return section.topics.first { $0.id == topicId }
    }
}
