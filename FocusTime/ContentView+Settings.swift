import SwiftUI
import ServiceManagement
import UserNotifications
import AppKit
import UniformTypeIdentifiers

extension ContentView {
    // MARK: - Settings View
    var settingsView: some View {
        VStack(spacing: 14) {
            
            Text("Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Durations (minutes)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Work:")
                        .frame(width: 80, alignment: .leading)
                    Stepper("\(timerState.workMinutes) min", value: $timerState.workMinutes, in: 1...60)
                        .onChange(of: timerState.workMinutes) { _ in
                            if timerState.mode == .work && !timerState.isRunning {
                                timerState.timeRemaining = timerState.workDuration
                            }
                        }
                }
                .font(.caption)
                
                HStack {
                    Text("Short Break:")
                        .frame(width: 80, alignment: .leading)
                    Stepper("\(timerState.shortBreakMinutes) min", value: $timerState.shortBreakMinutes, in: 1...30)
                        .onChange(of: timerState.shortBreakMinutes) { _ in
                            if timerState.mode == .shortBreak && !timerState.isRunning {
                                timerState.timeRemaining = timerState.shortBreakDuration
                            }
                        }
                }
                .font(.caption)
                
                HStack {
                    Text("Long Break:")
                        .frame(width: 80, alignment: .leading)
                    Stepper("\(timerState.longBreakMinutes) min", value: $timerState.longBreakMinutes, in: 1...60)
                        .onChange(of: timerState.longBreakMinutes) { _ in
                            if timerState.mode == .longBreak && !timerState.isRunning {
                                timerState.timeRemaining = timerState.longBreakDuration
                            }
                        }
                }
                .font(.caption)
            }
            
            Divider()
            
            HStack {
                Text("Daily Goal:")
                    .font(.caption)
                Stepper("\(timerState.dailyGoal) sessions", value: $timerState.dailyGoal, in: 1...20)
                    .font(.caption)
            }
            
            Divider()
            
            HStack {
                Text("Session Tags")
                    .font(.caption)
                
                Spacer()
                
                Button("Manage") {
                    showTagManager = true
                    showSettings = false
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Backup")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("Export JSON") {
                        exportBackup()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    
                    Button("Import JSON") {
                        importBackup()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                
                if let backupResult = backupResult {
                    Text(backupResult)
                        .font(.caption2)
                        .foregroundColor(backupResult.hasPrefix("✓") ? .green : .red)
                }
            }
            
            Divider()
            
            // Notion Integration
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "link.icloud")
                        .font(.caption)
                    Text("Notion Sync")
                        .font(.caption)
                }
                
                Spacer()
                
                Circle()
                    .fill(NotionConfig.isConfigured && NotionConfig.syncEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Button("Configure") {
                    showNotionSettings = true
                    showSettings = false
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Sound Alert", isOn: $soundEnabled)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
                
                HStack {
                    Toggle("Focus Mode", isOn: $focusModeEnabled)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    
                    Image(systemName: "moon.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
            
            Divider()
            
            HStack {
                Text("Shortcut:")
                    .font(.caption)
                Spacer()
                Text("⌘⇧F")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Button("← Back") {
                showSettings = false
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }
    
    // MARK: - Helper Methods
    
    func testNotionConnection() {
        isTestingConnection = true
        connectionTestResult = nil
        
        Task {
            let success = await notionService.testConnection()
            await MainActor.run {
                isTestingConnection = false
                connectionTestResult = success ? "✓ Connected" : "✗ Failed"
            }
        }
    }
    
    func syncAllHistory() {
        let history = timerState.sessionHistory.getHistoryForSync()
        let workMinutes = timerState.sessionHistory.workMinutes
        
        Task {
            let (success, failed) = await notionService.syncAllHistory(
                history: history,
                workMinutes: workMinutes
            )
            await MainActor.run {
                if failed == 0 {
                    notionService.lastSyncStatus = "✓ Synced \(success) days"
                } else {
                    notionService.lastSyncStatus = "✓ \(success) synced, \(failed) failed"
                }
            }
        }
    }
    
    func exportBackup() {
        do {
            let data = try timerState.sessionHistory.exportBackupData()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "FocusTime Backup \(backupDateString()).json"
            panel.canCreateDirectories = true
            
            if panel.runModal() == .OK, let url = panel.url {
                try data.write(to: url, options: [.atomic])
                backupResult = "✓ Exported backup"
            }
        } catch {
            backupResult = "✗ \(error.localizedDescription)"
        }
    }
    
    func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                try timerState.sessionHistory.importBackupData(data)
                timerState.timeRemaining = timerState.currentModeDuration()
                timerState.saveRuntimeStatus()
                backupResult = "✓ Imported backup"
            } catch {
                backupResult = "✗ \(error.localizedDescription)"
            }
        }
    }
    
    func backupDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // MARK: - Helper Views
    
    func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Computed Properties
    
    var modeColor: Color {
        switch timerState.mode {
        case .work:
            return .red
        case .shortBreak:
            return .green
        case .longBreak:
            return .blue
        }
    }
    
    // MARK: - Calendar Helper Functions
    
    func sessionColor(count: Int) -> Color {
        switch count {
        case 1...2:
            return .green.opacity(0.6)
        case 3...4:
            return .orange.opacity(0.7)
        default:
            return .red.opacity(0.8)
        }
    }
    
    func generateMonthDays(for date: Date) -> [Date?] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let firstOfMonth = calendar.date(from: components) else { return [] }
        
        var weekday = calendar.component(.weekday, from: firstOfMonth)
        weekday = (weekday + 5) % 7
        
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return [] }
        let numDays = range.count
        
        var days: [Date?] = Array(repeating: nil, count: weekday)
        
        for day in 1...numDays {
            if let dayDate = calendar.date(bySetting: .day, value: day, of: firstOfMonth) {
                days.append(dayDate)
            }
        }
        
        return days
    }
    
    func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Launch at Login
    
    func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
    
    // MARK: - Notifications
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
}
