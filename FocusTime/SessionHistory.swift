//
//  SessionHistory.swift
//  FocusTime
//
//  Created by Duncan Njoroge on 25/01/2026.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Session Tag
struct SessionTag: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    var isDefault: Bool
    
    init(name: String, colorHex: String, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.isDefault = isDefault
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
    
    // Predefined tags - includes K8s and Homelab for Road to Mastery integration
    static let coding = SessionTag(name: "Coding", colorHex: "#4CAF50", isDefault: true)
    static let writing = SessionTag(name: "Writing", colorHex: "#2196F3", isDefault: true)
    static let study = SessionTag(name: "Study", colorHex: "#FF9800", isDefault: true)
    static let work = SessionTag(name: "Work", colorHex: "#9C27B0", isDefault: true)
    static let reading = SessionTag(name: "Reading", colorHex: "#00BCD4", isDefault: true)
    static let k8s = SessionTag(name: "K8s", colorHex: "#326CE5", isDefault: true)  // Kubernetes blue
    static let homelab = SessionTag(name: "Homelab", colorHex: "#E91E63", isDefault: true)  // Pink
    static let other = SessionTag(name: "Other", colorHex: "#607D8B", isDefault: true)
    
    static let defaultTags: [SessionTag] = [.coding, .writing, .study, .work, .reading, .k8s, .homelab, .other]
}

// MARK: - Tagged Session Entry
struct TaggedSession: Codable {
    var tag: String
    var count: Int
}

// MARK: - Session History Manager
class SessionHistory: ObservableObject {
    
    @Published private(set) var history: [String: [TaggedSession]] = [:]
    @Published var availableTags: [SessionTag] = []
    
    private let storageKey = "sessionHistoryTagged"
    private let tagsStorageKey = "savedTags_v3"  // Bumped version for new default tags
    private let legacyStorageKey = "sessionHistory"
    
    var workMinutes: Int = 25  // Set by TimerState
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    init() {
        loadTags()
        loadHistory()
        migrateLegacyData()
    }
    
    // MARK: - Public Methods
    
    func todayKey() -> String {
        return dateFormatter.string(from: Date())
    }
    
    func todaySessions() -> Int {
        guard let todayData = history[todayKey()] else { return 0 }
        return todayData.reduce(0) { $0 + $1.count }
    }
    
    func todaySessions(for tag: String) -> Int {
        guard let todayData = history[todayKey()] else { return 0 }
        return todayData.first(where: { $0.tag == tag })?.count ?? 0
    }
    
    func addSession(tag: String) {
        let key = todayKey()
        var dayData = history[key] ?? []
        
        if let index = dayData.firstIndex(where: { $0.tag == tag }) {
            dayData[index].count += 1
        } else {
            dayData.append(TaggedSession(tag: tag, count: 1))
        }
        
        history[key] = dayData
        saveHistory()
        
        // Sync to Notion
        syncToNotion()
    }
    
    func sessions(for date: Date) -> Int {
        let key = dateFormatter.string(from: date)
        guard let dayData = history[key] else { return 0 }
        return dayData.reduce(0) { $0 + $1.count }
    }
    
    func sessionsByTag(for date: Date) -> [TaggedSession] {
        let key = dateFormatter.string(from: date)
        return history[key] ?? []
    }
    
    func resetToday() {
        history[todayKey()] = []
        saveHistory()
    }
    
    func dateFromKey(_ key: String) -> Date? {
        return dateFormatter.date(from: key)
    }
    
    // MARK: - Notion Sync
    
    private func syncToNotion() {
        let today = Date()
        let sessions = todaySessions()
        let tagBreakdown = todaySessionsByTag()
        
        Task {
            await NotionService.shared.syncSession(
                date: today,
                sessions: sessions,
                tagBreakdown: tagBreakdown,
                workMinutes: workMinutes
            )
        }
    }
    
    func todaySessionsByTag() -> [String: Int] {
        guard let todayData = history[todayKey()] else { return [:] }
        var result: [String: Int] = [:]
        for session in todayData {
            result[session.tag] = session.count
        }
        return result
    }
    
    func manualSync() {
        syncToNotion()
    }
    
    /// Returns all historical data formatted for Notion sync
    func getHistoryForSync() -> [String: [(tag: String, count: Int)]] {
        var result: [String: [(tag: String, count: Int)]] = [:]
        for (date, sessions) in history {
            result[date] = sessions.map { (tag: $0.tag, count: $0.count) }
        }
        return result
    }
    
    // MARK: - Tag Management
    
    func addCustomTag(name: String, colorHex: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard !availableTags.contains(where: { $0.name.lowercased() == name.lowercased() }) else { return }
        
        let tag = SessionTag(name: name, colorHex: colorHex, isDefault: false)
        availableTags.append(tag)
        saveTags()
    }
    
    func removeCustomTag(name: String) {
        guard let tag = availableTags.first(where: { $0.name == name }), !tag.isDefault else { return }
        availableTags.removeAll { $0.name == name }
        saveTags()
    }
    
    func updateTag(oldName: String, newName: String, newColorHex: String) {
        guard let index = availableTags.firstIndex(where: { $0.name == oldName }) else { return }
        
        let wasDefault = availableTags[index].isDefault
        availableTags[index] = SessionTag(name: newName, colorHex: newColorHex, isDefault: wasDefault)
        saveTags()
        
        // Update historical data if name changed
        if oldName != newName {
            var updated = false
            for (date, var dayData) in history {
                if let sessionIndex = dayData.firstIndex(where: { $0.tag == oldName }) {
                    dayData[sessionIndex] = TaggedSession(tag: newName, count: dayData[sessionIndex].count)
                    history[date] = dayData
                    updated = true
                }
            }
            if updated {
                saveHistory()
            }
        }
    }
    
    func getTag(byName name: String) -> SessionTag? {
        return availableTags.first { $0.name == name }
    }
    
    func resetTagsToDefaults() {
        availableTags = SessionTag.defaultTags
        saveTags()
    }
    
    // MARK: - Statistics
    
    func thisWeekSessions() -> Int {
        let calendar = Calendar.current
        let today = Date()
        
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return 0
        }
        let weekStart = weekInterval.start
        
        var total = 0
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                total += sessions(for: date)
            }
        }
        return total
    }
    
    func thisMonthSessions() -> Int {
        let calendar = Calendar.current
        let today = Date()
        let year = calendar.component(.year, from: today)
        let month = calendar.component(.month, from: today)
        
        var total = 0
        for (key, dayData) in history {
            if let date = dateFormatter.date(from: key) {
                let dateYear = calendar.component(.year, from: date)
                let dateMonth = calendar.component(.month, from: date)
                if dateYear == year && dateMonth == month {
                    total += dayData.reduce(0) { $0 + $1.count }
                }
            }
        }
        return total
    }
    
    func allTimeSessions() -> Int {
        var total = 0
        for (_, dayData) in history {
            total += dayData.reduce(0) { $0 + $1.count }
        }
        return total
    }
    
    func allTimeSessionsByTag() -> [String: Int] {
        var tagCounts: [String: Int] = [:]
        
        for (_, dayData) in history {
            for session in dayData {
                tagCounts[session.tag, default: 0] += session.count
            }
        }
        
        return tagCounts
    }
    
    func thisWeekSessionsByTag() -> [String: Int] {
        let calendar = Calendar.current
        let today = Date()
        
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return [:]
        }
        let weekStart = weekInterval.start
        
        var tagCounts: [String: Int] = [:]
        
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                let dayData = sessionsByTag(for: date)
                for session in dayData {
                    tagCounts[session.tag, default: 0] += session.count
                }
            }
        }
        
        return tagCounts
    }
    
    func todayFocusMinutes(workMinutes: Int = 25) -> Int {
        return todaySessions() * workMinutes
    }
    
    func formatFocusTime(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
    
    // MARK: - Streak Calculation
    
    func currentStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()
        
        if todaySessions() > 0 {
            streak = 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        } else {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        
        while true {
            let count = sessions(for: checkDate)
            if count > 0 {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        
        return streak
    }
    
    func longestStreak() -> Int {
        guard !history.isEmpty else { return 0 }
        
        let datesWithSessions = history.compactMap { (key, value) -> Date? in
            let count = value.reduce(0) { $0 + $1.count }
            guard count > 0 else { return nil }
            return dateFormatter.date(from: key)
        }.sorted()
        
        guard !datesWithSessions.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var longestStreak = 1
        var currentStreak = 1
        
        for i in 1..<datesWithSessions.count {
            let previousDate = datesWithSessions[i - 1]
            let currentDate = datesWithSessions[i]
            
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: previousDate),
               calendar.isDate(nextDay, inSameDayAs: currentDate) {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }
        
        return longestStreak
    }
    
    // MARK: - Persistence
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: [TaggedSession]].self, from: data) {
            history = decoded
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadTags() {
        if let data = UserDefaults.standard.data(forKey: tagsStorageKey),
           let savedTags = try? JSONDecoder().decode([SessionTag].self, from: data),
           !savedTags.isEmpty {
            availableTags = savedTags
        } else {
            availableTags = SessionTag.defaultTags
            saveTags()
        }
    }
    
    private func saveTags() {
        if let encoded = try? JSONEncoder().encode(availableTags) {
            UserDefaults.standard.set(encoded, forKey: tagsStorageKey)
        }
    }
    
    private func migrateLegacyData() {
        if let oldData = UserDefaults.standard.dictionary(forKey: legacyStorageKey) as? [String: Int],
           !oldData.isEmpty {
            
            if history.isEmpty {
                for (date, count) in oldData {
                    if count > 0 {
                        history[date] = [TaggedSession(tag: "Other", count: count)]
                    }
                }
                saveHistory()
            }
            
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        }
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else { return nil }
        
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
