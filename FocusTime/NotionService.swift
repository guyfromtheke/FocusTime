//
//  NotionService.swift
//  FocusTime
//
//  Created by Duncan Njoroge on 27/02/2026.
//
//  Using Notion API version 2022-06-28 (stable, widely supported)
//

import Foundation
import SwiftUI
import Combine
import Security
import OSLog

// MARK: - Notion Configuration
struct NotionConfig {
    private static let apiKeyDefaultsKey = "notionApiKey"
    private static let databaseIdDefaultsKey = "notionDatabaseId"
    private static let roadToMasteryDatabaseIdDefaultsKey = "notionRoadToMasteryDatabaseId"
    private static let keychainService = "FocusTime.Notion"
    private static let keychainAccount = "notionApiKey"
    
    static var apiKey: String {
        get {
            if let token = KeychainStore.read(service: keychainService, account: keychainAccount) {
                return token
            }
            
            if let legacyToken = UserDefaults.standard.string(forKey: apiKeyDefaultsKey), !legacyToken.isEmpty {
                KeychainStore.save(legacyToken, service: keychainService, account: keychainAccount)
                UserDefaults.standard.removeObject(forKey: apiKeyDefaultsKey)
                return legacyToken
            }
            
            return ""
        }
        set {
            let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedValue.isEmpty {
                KeychainStore.delete(service: keychainService, account: keychainAccount)
            } else {
                KeychainStore.save(trimmedValue, service: keychainService, account: keychainAccount)
            }
            UserDefaults.standard.removeObject(forKey: apiKeyDefaultsKey)
        }
    }
    
    static var databaseId: String {
        get { UserDefaults.standard.string(forKey: databaseIdDefaultsKey) ?? "" }
        set { UserDefaults.standard.set(cleanDatabaseId(newValue), forKey: databaseIdDefaultsKey) }
    }
    
    static var roadToMasteryDatabaseId: String {
        get { UserDefaults.standard.string(forKey: roadToMasteryDatabaseIdDefaultsKey) ?? "" }
        set { UserDefaults.standard.set(cleanDatabaseId(newValue), forKey: roadToMasteryDatabaseIdDefaultsKey) }
    }
    
    static var isConfigured: Bool {
        !apiKey.isEmpty && !databaseId.isEmpty
    }
    
    static var syncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notionSyncEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notionSyncEnabled") }
    }
    
    private static func cleanDatabaseId(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
    }
}

// MARK: - Keychain Storage
enum KeychainStore {
    static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    static func save(_ value: String, service: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }
    
    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Notion API Response Models
struct NotionQueryResponse: Codable {
    let results: [NotionPage]
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case results
        case hasMore = "has_more"
    }
}

struct NotionPage: Codable {
    let id: String
    let url: String?
    let properties: [String: NotionProperty]?
}

struct NotionProperty: Codable {
    let type: String
    let number: Double?
    let richText: [NotionRichText]?
    let title: [NotionRichText]?
    let date: NotionDate?
    let relation: [NotionRelation]?
    
    enum CodingKeys: String, CodingKey {
        case type, number, title, date, relation
        case richText = "rich_text"
    }
}

struct NotionRichText: Codable {
    let plainText: String?
    let text: NotionText?
    
    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
        case text
    }
}

struct NotionText: Codable {
    let content: String
}

struct NotionDate: Codable {
    let start: String?
    let end: String?
}

struct NotionRelation: Codable {
    let id: String
}

// MARK: - History Sync Progress
struct HistorySyncProgress {
    var total: Int
    var completed: Int
    var currentDate: String
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total) * 100
    }
}

// MARK: - Notion Service
class NotionService: ObservableObject {
    static let shared = NotionService()
    
    @Published var lastSyncStatus: String = ""
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var historySyncProgress: HistorySyncProgress?
    @Published var isSyncingHistory: Bool = false
    
    private let baseURL = "https://api.notion.com/v1"
    
    // Using stable API version
    private let apiVersion = "2022-06-28"
    
    private init() {}
    
    // MARK: - Public Methods
    
    func syncSession(date: Date, sessions: Int, tagBreakdown: [String: Int], workMinutes: Int) async -> Bool {
        guard NotionConfig.isConfigured && NotionConfig.syncEnabled else {
            await MainActor.run {
                lastSyncStatus = "Sync disabled"
            }
            return true
        }
        
        await MainActor.run {
            isSyncing = true
            lastSyncStatus = "Syncing..."
        }
        
        do {
            // Format data
            let dateString = formatDate(date)
            let tagsString = formatTags(tagBreakdown)
            let focusTime = formatFocusTime(sessions: sessions, workMinutes: workMinutes)
            let dayName = formatDayName(date)
            
            // Find Road to Mastery entry for today (to link)
            let roadToMasteryPageId = await findRoadToMasteryEntry(for: date)
            
            // Check if today's FocusTime entry exists
            if let existingPage = await findEntryByDate(date: date) {
                // Update existing entry
                try await updatePage(
                    pageId: existingPage.id,
                    sessions: sessions,
                    tags: tagsString,
                    focusTime: focusTime,
                    roadToMasteryId: roadToMasteryPageId
                )
                await MainActor.run {
                    lastSyncStatus = "✓ Updated"
                    lastSyncTime = Date()
                }
            } else {
                // Create new entry
                try await createPage(
                    name: dayName,
                    date: dateString,
                    sessions: sessions,
                    tags: tagsString,
                    focusTime: focusTime,
                    roadToMasteryId: roadToMasteryPageId
                )
                await MainActor.run {
                    lastSyncStatus = "✓ Created"
                    lastSyncTime = Date()
                }
            }
            
            await MainActor.run {
                isSyncing = false
            }
            return true
        } catch {
            await MainActor.run {
                lastSyncStatus = "✗ \(error.localizedDescription)"
            }
            AppLog.notion.error("Notion sync error: \(error.localizedDescription, privacy: .public)")
        }
        
        await MainActor.run {
            isSyncing = false
        }
        return false
    }
    
    /// Sync all historical sessions to Notion
    func syncAllHistory(history: [String: [(tag: String, count: Int)]], workMinutes: Int) async -> (success: Int, failed: Int) {
        guard NotionConfig.isConfigured else {
            return (0, 0)
        }
        
        await MainActor.run {
            isSyncingHistory = true
            historySyncProgress = HistorySyncProgress(total: history.count, completed: 0, currentDate: "")
        }
        
        var successCount = 0
        var failedCount = 0
        
        // Sort dates chronologically
        let sortedDates = history.keys.sorted()
        
        for (index, dateKey) in sortedDates.enumerated() {
            guard let sessions = history[dateKey] else { continue }
            
            await MainActor.run {
                historySyncProgress = HistorySyncProgress(
                    total: history.count,
                    completed: index,
                    currentDate: dateKey
                )
            }
            
            // Convert to the format we need
            let totalSessions = sessions.reduce(0) { $0 + $1.count }
            var tagBreakdown: [String: Int] = [:]
            for session in sessions {
                tagBreakdown[session.tag] = session.count
            }
            
            // Parse the date
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: dateKey) else {
                failedCount += 1
                continue
            }
            
            do {
                let dateString = dateKey
                let tagsString = formatTags(tagBreakdown)
                let focusTime = formatFocusTime(sessions: totalSessions, workMinutes: workMinutes)
                let dayName = formatDayName(date)
                
                // Find Road to Mastery entry for this date
                let roadToMasteryPageId = await findRoadToMasteryEntry(for: date)
                
                // Check if entry already exists
                if let existingPage = await findEntryByDate(date: date) {
                    // Update existing entry
                    try await updatePage(
                        pageId: existingPage.id,
                        sessions: totalSessions,
                        tags: tagsString,
                        focusTime: focusTime,
                        roadToMasteryId: roadToMasteryPageId
                    )
                } else {
                    // Create new entry
                    try await createPage(
                        name: dayName,
                        date: dateString,
                        sessions: totalSessions,
                        tags: tagsString,
                        focusTime: focusTime,
                        roadToMasteryId: roadToMasteryPageId
                    )
                }
                
                successCount += 1
                
                // Small delay to avoid rate limiting
                try await Task.sleep(nanoseconds: 350_000_000) // 350ms
                
            } catch {
                AppLog.notion.error("Failed to sync \(dateKey, privacy: .public): \(error.localizedDescription, privacy: .public)")
                failedCount += 1
            }
        }
        
        await MainActor.run {
            isSyncingHistory = false
            historySyncProgress = nil
            lastSyncStatus = "✓ History synced"
            lastSyncTime = Date()
        }
        
        return (successCount, failedCount)
    }
    
    func testConnection() async -> Bool {
        guard NotionConfig.isConfigured else { return false }
        
        do {
            // Test by retrieving the database
            let url = URL(string: "\(baseURL)/databases/\(NotionConfig.databaseId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            addHeaders(to: &request)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return true
                } else {
                    if let errorString = String(data: data, encoding: .utf8) {
                        AppLog.notion.error("Test connection error (\(httpResponse.statusCode)): \(errorString, privacy: .public)")
                    }
                    return false
                }
            }
            return false
        } catch {
            AppLog.notion.error("Connection test failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func findEntryByDate(date: Date) async -> NotionPage? {
        let dateString = formatDate(date)
        
        let filter: [String: Any] = [
            "filter": [
                "property": "Date",
                "date": [
                    "equals": dateString
                ]
            ]
        ]
        
        do {
            let url = URL(string: "\(baseURL)/databases/\(NotionConfig.databaseId)/query")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            addHeaders(to: &request)
            request.httpBody = try JSONSerialization.data(withJSONObject: filter)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let errorString = String(data: data, encoding: .utf8) {
                    AppLog.notion.error("Query error (\(httpResponse.statusCode)): \(errorString, privacy: .public)")
                }
                return nil
            }
            
            let queryResponse = try JSONDecoder().decode(NotionQueryResponse.self, from: data)
            return queryResponse.results.first
        } catch {
            AppLog.notion.error("Error finding entry: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    private func findRoadToMasteryEntry(for date: Date) async -> String? {
        guard !NotionConfig.roadToMasteryDatabaseId.isEmpty else {
            return nil
        }
        
        let dateString = formatDate(date)
        
        let filter: [String: Any] = [
            "filter": [
                "property": "Date",
                "date": [
                    "equals": dateString
                ]
            ]
        ]
        
        do {
            let url = URL(string: "\(baseURL)/databases/\(NotionConfig.roadToMasteryDatabaseId)/query")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            addHeaders(to: &request)
            request.httpBody = try JSONSerialization.data(withJSONObject: filter)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let errorString = String(data: data, encoding: .utf8) {
                    AppLog.notion.error("Road to Mastery query error (\(httpResponse.statusCode)): \(errorString, privacy: .public)")
                }
                return nil
            }
            
            let queryResponse = try JSONDecoder().decode(NotionQueryResponse.self, from: data)
            return queryResponse.results.first?.id
        } catch {
            AppLog.notion.error("Error finding Road to Mastery entry: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    private func createPage(name: String, date: String, sessions: Int, tags: String, focusTime: String, roadToMasteryId: String?) async throws {
        let url = URL(string: "\(baseURL)/pages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        
        var properties: [String: Any] = [
            "Name": [
                "title": [
                    ["text": ["content": name]]
                ]
            ],
            "Date": [
                "date": ["start": date]
            ],
            "Sessions": [
                "number": sessions
            ],
            "Tags": [
                "rich_text": [
                    ["text": ["content": tags]]
                ]
            ],
            "Focus Time": [
                "rich_text": [
                    ["text": ["content": focusTime]]
                ]
            ]
        ]
        
        // Add relation to Road to Mastery if we found today's entry
        if let rtmId = roadToMasteryId {
            properties["Road to Mastery"] = [
                "relation": [
                    ["id": rtmId]
                ]
            ]
        }
        
        // Use database_id as parent (API 2022-06-28)
        let body: [String: Any] = [
            "parent": [
                "database_id": NotionConfig.databaseId
            ],
            "properties": properties
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                AppLog.notion.error("Create page error (\(httpResponse.statusCode)): \(errorString, privacy: .public)")
            }
            throw NotionError.createFailed(statusCode: httpResponse.statusCode)
        }
    }
    
    private func updatePage(pageId: String, sessions: Int, tags: String, focusTime: String, roadToMasteryId: String?) async throws {
        let url = URL(string: "\(baseURL)/pages/\(pageId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        addHeaders(to: &request)
        
        var properties: [String: Any] = [
            "Sessions": [
                "number": sessions
            ],
            "Tags": [
                "rich_text": [
                    ["text": ["content": tags]]
                ]
            ],
            "Focus Time": [
                "rich_text": [
                    ["text": ["content": focusTime]]
                ]
            ]
        ]
        
        // Update Road to Mastery relation if available
        if let rtmId = roadToMasteryId {
            properties["Road to Mastery"] = [
                "relation": [
                    ["id": rtmId]
                ]
            ]
        }
        
        let body: [String: Any] = [
            "properties": properties
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                AppLog.notion.error("Update page error (\(httpResponse.statusCode)): \(errorString, privacy: .public)")
            }
            throw NotionError.updateFailed(statusCode: httpResponse.statusCode)
        }
    }
    
    private func addHeaders(to request: inout URLRequest) {
        request.setValue("Bearer \(NotionConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
    // MARK: - Formatting Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formatDayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE - MMM d"
        return formatter.string(from: date)
    }
    
    private func formatTags(_ tagBreakdown: [String: Int]) -> String {
        guard !tagBreakdown.isEmpty else { return "None" }
        let sorted = tagBreakdown.sorted { $0.value > $1.value }
        return sorted.map { "\($0.key) (\($0.value))" }.joined(separator: ", ")
    }
    
    private func formatFocusTime(sessions: Int, workMinutes: Int) -> String {
        let totalMinutes = sessions * workMinutes
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Errors
enum NotionError: LocalizedError {
    case createFailed(statusCode: Int)
    case updateFailed(statusCode: Int)
    case notConfigured
    
    var errorDescription: String? {
        switch self {
        case .createFailed(let code):
            return "Create failed (HTTP \(code))"
        case .updateFailed(let code):
            return "Update failed (HTTP \(code))"
        case .notConfigured:
            return "API key not configured"
        }
    }
}
