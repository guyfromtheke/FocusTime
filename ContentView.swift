//
//  ContentView.swift
//  FocusTime
//
//  Created by Duncan Njoroge on 25/01/2026.
//

import SwiftUI
import UserNotifications
import ServiceManagement
import AVFoundation

// MARK: - Main Content View
struct ContentView: View {
    @ObservedObject var timerState: TimerState
    @StateObject private var notionService = NotionService.shared
    
    var onStartPause: () -> Void
    var onReset: () -> Void
    var onSwitchMode: () -> Void
    var onTagSelected: (String) -> Void
    
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showCalendar = false
    @State private var showHeatmap = false
    @State private var showTagStats = false
    @State private var showTagManager = false
    @State private var showNotionSettings = false
    @State private var selectedDate = Date()
    @State private var newTagName = ""
    @State private var newTagColor = Color.blue
    @State private var showEditTag = false
    @State private var editingTag: SessionTag? = nil
    @State private var editTagName = ""
    @State private var editTagColor = Color.blue
    
    // Notion settings
    @State private var notionApiKey = NotionConfig.apiKey
    @State private var notionSyncEnabled = NotionConfig.syncEnabled
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?
    @State private var historySyncResult: String?
    
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("focusModeEnabled") private var focusModeEnabled = true
    
    var body: some View {
        VStack(spacing: 16) {
            if timerState.showTagPicker {
                tagPickerView
            } else if showNotionSettings {
                notionSettingsView
            } else if showTagManager {
                tagManagerView
            } else if showSettings {
                settingsView
            } else if showTagStats {
                tagStatsView
            } else if showHeatmap {
                HeatmapView(timerState: timerState, isPresented: $showHeatmap)
            } else if showCalendar {
                calendarView
            } else if showHistory {
                historyView
            } else {
                timerView
            }
        }
        .padding(24)
        .frame(width: (showHeatmap || showTagStats || showTagManager || showNotionSettings) ? 320 : 280)
        .onAppear {
            requestNotificationPermission()
        }
    }
    
    // MARK: - Tag Picker View
    var tagPickerView: some View {
        VStack(spacing: 16) {
            Text("Session Complete! 🎉")
                .font(.headline)
            
            Text("What were you working on?")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(timerState.sessionHistory.availableTags) { tag in
                    Button(action: {
                        onTagSelected(tag.name)
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 10, height: 10)
                            Text(tag.name)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
            
            Button("Skip") {
                onTagSelected("Other")
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Timer View
    var timerView: some View {
        VStack(spacing: 16) {
            
            HStack(spacing: 6) {
                Text(timerState.mode.rawValue)
                    .font(.headline)
                    .foregroundColor(modeColor)
                
                if timerState.mode == .work && focusModeEnabled && timerState.isRunning {
                    Image(systemName: "moon.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                
                // Notion sync indicator
                if NotionConfig.syncEnabled && NotionConfig.isConfigured {
                    if notionService.isSyncing {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    } else if notionService.lastSyncStatus.hasPrefix("✓") {
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                PieSlice(progress: 1.0 - timerState.progress())
                    .fill(modeColor.opacity(0.8))
                    .frame(width: 120, height: 120)
                    .animation(.linear(duration: 0.5), value: timerState.progress())
                
                Circle()
                    .fill(Color(NSColor.windowBackgroundColor))
                    .frame(width: 70, height: 70)
                
                Text(formatTime(timerState.timeRemaining))
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
            }
            
            HStack(spacing: 8) {
                ForEach(0..<timerState.totalSessionsGoal, id: \.self) { index in
                    let todayCount = timerState.todaySessions()
                    let completedInCycle = todayCount % timerState.sessionsBeforeLongBreak
                    let filled = todayCount > 0 && completedInCycle == 0
                        ? index < timerState.sessionsBeforeLongBreak
                        : index < completedInCycle
                    Circle()
                        .fill(filled ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            
            VStack(spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(timerState.dailyGoalReached() ? Color.green : Color.accentColor)
                            .frame(width: geometry.size.width * timerState.dailyGoalProgress(), height: 8)
                            .animation(.easeInOut(duration: 0.3), value: timerState.dailyGoalProgress())
                    }
                }
                .frame(height: 8)
                
                HStack {
                    if timerState.dailyGoalReached() {
                        Text("🎉 Goal reached!")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("\(timerState.todaySessions())/\(timerState.dailyGoal) daily goal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    let streak = timerState.sessionHistory.currentStreak()
                    if streak > 0 {
                        Text("🔥 \(streak)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            HStack(spacing: 16) {
                Button(timerState.isRunning ? "Pause" : "Start") {
                    onStartPause()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Reset") {
                    onReset()
                }
                .buttonStyle(.bordered)
            }
            
            Button(timerState.mode == .work ? "Skip to Break" : "Skip to Work") {
                onSwitchMode()
            }
            .buttonStyle(.borderless)
            .font(.caption)
            
            Text("⌘⇧F to start/pause")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Divider()
            
            HStack {
                Button("Settings") {
                    showSettings = true
                }
                .buttonStyle(.borderless)
                .font(.caption)
                
                Spacer()
                
                Button("History") {
                    showHistory = true
                }
                .buttonStyle(.borderless)
                .font(.caption)
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - History View
    var historyView: some View {
        VStack(spacing: 16) {
            Text("History")
                .font(.headline)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Today")
                    Spacer()
                    Text("\(timerState.sessionHistory.todaySessions()) sessions")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                
                HStack {
                    Text("This Week")
                    Spacer()
                    Text("\(timerState.sessionHistory.thisWeekSessions()) sessions")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                
                HStack {
                    Text("This Month")
                    Spacer()
                    Text("\(timerState.sessionHistory.thisMonthSessions()) sessions")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                
                HStack {
                    Text("All Time")
                    Spacer()
                    Text("\(timerState.sessionHistory.allTimeSessions()) sessions")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Divider()
            
            VStack(spacing: 8) {
                HStack {
                    Text("🔥 Current Streak")
                    Spacer()
                    Text("\(timerState.sessionHistory.currentStreak()) days")
                        .foregroundColor(.orange)
                }
                .font(.caption)
                
                HStack {
                    Text("🏆 Longest Streak")
                    Spacer()
                    Text("\(timerState.sessionHistory.longestStreak()) days")
                        .foregroundColor(.yellow)
                }
                .font(.caption)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Divider()
            
            let focusMinutes = timerState.sessionHistory.todayFocusMinutes(workMinutes: timerState.workMinutes)
            Text("Today's focus: \(timerState.sessionHistory.formatFocusTime(minutes: focusMinutes))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button("📅 Calendar") {
                        showCalendar = true
                        showHistory = false
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    
                    Button("🟩 Heatmap") {
                        showHeatmap = true
                        showHistory = false
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                
                Button("🏷️ Tag Statistics") {
                    showTagStats = true
                    showHistory = false
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            
            Button("← Back") {
                showHistory = false
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }
    
    // MARK: - Tag Statistics View
    var tagStatsView: some View {
        VStack(spacing: 12) {
            Text("Tag Statistics")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("All Time")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let allTimeStats = timerState.sessionHistory.allTimeSessionsByTag()
                let totalSessions = timerState.sessionHistory.allTimeSessions()
                
                if allTimeStats.isEmpty {
                    Text("No sessions recorded yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(allTimeStats.sorted(by: { $0.value > $1.value }), id: \.key) { tag, count in
                        tagStatRow(tag: tag, count: count, total: totalSessions)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("This Week")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let weekStats = timerState.sessionHistory.thisWeekSessionsByTag()
                let weekTotal = timerState.sessionHistory.thisWeekSessions()
                
                if weekStats.isEmpty {
                    Text("No sessions this week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(weekStats.sorted(by: { $0.value > $1.value }), id: \.key) { tag, count in
                        tagStatRow(tag: tag, count: count, total: weekTotal)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Divider()
            
            let allTimeStatsForFocus = timerState.sessionHistory.allTimeSessionsByTag()
            if !allTimeStatsForFocus.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus Time by Tag")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(allTimeStatsForFocus.sorted(by: { $0.value > $1.value }), id: \.key) { tag, count in
                        let minutes = count * timerState.workMinutes
                        HStack {
                            if let sessionTag = timerState.sessionHistory.getTag(byName: tag) {
                                Circle()
                                    .fill(sessionTag.color)
                                    .frame(width: 8, height: 8)
                            }
                            Text(tag)
                                .font(.caption2)
                            Spacer()
                            Text(timerState.sessionHistory.formatFocusTime(minutes: minutes))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button("← Back") {
                showTagStats = false
                showHistory = true
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }
    
    // MARK: - Tag Stat Row
    func tagStatRow(tag: String, count: Int, total: Int) -> some View {
        let percentage = total > 0 ? Double(count) / Double(total) : 0
        let sessionTag = timerState.sessionHistory.getTag(byName: tag)
        
        return VStack(spacing: 4) {
            HStack {
                if let sessionTag = sessionTag {
                    Circle()
                        .fill(sessionTag.color)
                        .frame(width: 10, height: 10)
                }
                Text(tag)
                    .font(.caption)
                Spacer()
                Text("\(count) (\(Int(percentage * 100))%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(sessionTag?.color ?? Color.gray)
                        .frame(width: geometry.size.width * percentage, height: 4)
                }
            }
            .frame(height: 4)
        }
    }
    
    // MARK: - Tag Manager View
    var tagManagerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Manage Tags")
                    .font(.headline)
                
                Spacer()
                
                Button("Reset") {
                    timerState.sessionHistory.resetTagsToDefaults()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .foregroundColor(.orange)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(timerState.sessionHistory.availableTags) { tag in
                        HStack {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 12, height: 12)
                            
                            Text(tag.name)
                                .font(.caption)
                            
                            Spacer()
                            
                            Button {
                                editingTag = tag
                                editTagName = tag.name
                                editTagColor = tag.color
                                showEditTag = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                            
                            if tag.isDefault {
                                Text("default")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 45)
                            } else {
                                Button {
                                    timerState.sessionHistory.removeCustomTag(name: tag.name)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red.opacity(0.7))
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                                .frame(width: 45)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(4)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(maxHeight: 180)
            
            Divider()
            
            if showEditTag, let tag = editingTag {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Edit: \(tag.name)")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button("Cancel") {
                            showEditTag = false
                            editingTag = nil
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    
                    HStack {
                        TextField("Tag name", text: $editTagName)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        
                        ColorPicker("", selection: $editTagColor, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 30)
                    }
                    
                    Button("Save Changes") {
                        if !editTagName.isEmpty {
                            let hex = editTagColor.toHex() ?? "#607D8B"
                            timerState.sessionHistory.updateTag(oldName: tag.name, newName: editTagName, newColorHex: hex)
                            showEditTag = false
                            editingTag = nil
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption)
                    .disabled(editTagName.isEmpty)
                }
                .padding()
                .background(Color.blue.opacity(0.15))
                .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Custom Tag")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Tag name", text: $newTagName)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        
                        ColorPicker("", selection: $newTagColor, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 30)
                    }
                    
                    Button("Add Tag") {
                        if !newTagName.isEmpty {
                            let hex = newTagColor.toHex() ?? "#607D8B"
                            timerState.sessionHistory.addCustomTag(name: newTagName, colorHex: hex)
                            newTagName = ""
                            newTagColor = .blue
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .disabled(newTagName.isEmpty)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button("← Back") {
                showTagManager = false
                showSettings = true
                showEditTag = false
                editingTag = nil
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }
    
    // MARK: - Notion Settings View
    var notionSettingsView: some View {
        VStack(spacing: 12) {
            Text("Notion Integration")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable Sync", isOn: $notionSyncEnabled)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .onChange(of: notionSyncEnabled) { _, newValue in
                        NotionConfig.syncEnabled = newValue
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    SecureField("secret_...", text: $notionApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onChange(of: notionApiKey) { _, newValue in
                            NotionConfig.apiKey = newValue
                        }
                }
                
                HStack {
                    Button("Test Connection") {
                        testNotionConnection()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .disabled(notionApiKey.isEmpty || isTestingConnection)
                    
                    if isTestingConnection {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    
                    if let result = connectionTestResult {
                        Text(result)
                            .font(.caption2)
                            .foregroundColor(result.contains("✓") ? .green : .red)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Sync Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Circle()
                        .fill(NotionConfig.isConfigured && NotionConfig.syncEnabled ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(NotionConfig.isConfigured && NotionConfig.syncEnabled ? "Active" : "Disabled")
                        .font(.caption)
                    
                    Spacer()
                    
                    Text(notionService.lastSyncStatus)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let lastSync = notionService.lastSyncTime {
                    Text("Last sync: \(lastSync.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Button("Sync Now") {
                    timerState.sessionHistory.manualSync()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .disabled(!NotionConfig.isConfigured || !NotionConfig.syncEnabled)
                
                Divider()
                    .padding(.vertical, 4)
                
                // Sync All History
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sync All History")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("Upload all past sessions to Notion")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if notionService.isSyncingHistory, let progress = notionService.historySyncProgress {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: progress.percentage, total: 100)
                                .progressViewStyle(.linear)
                            
                            Text("Syncing \(progress.currentDate)... (\(progress.completed)/\(progress.total))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button("Sync History") {
                            syncAllHistory()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        .disabled(!NotionConfig.isConfigured || notionService.isSyncingHistory)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Setup Instructions")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("1. Go to notion.so/my-integrations")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("2. Create a new integration")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("3. Copy the API key and paste above")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("4. Share your FocusTime Log database with the integration")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            Button("← Back") {
                showNotionSettings = false
                showSettings = true
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }
    
    // MARK: - Calendar View
    var calendarView: some View {
        VStack(spacing: 12) {
            Text("Calendar")
                .font(.headline)
            
            HStack {
                Button("◀") {
                    selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text(monthYearString(from: selectedDate))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("▶") {
                    selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            
            HStack(spacing: 4) {
                ForEach(["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            
            let days = generateMonthDays(for: selectedDate)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { day in
                    if let day = day {
                        let sessions = timerState.sessionHistory.sessions(for: day)
                        let isToday = Calendar.current.isDateInToday(day)
                        
                        VStack(spacing: 2) {
                            Text("\(Calendar.current.component(.day, from: day))")
                                .font(.caption)
                                .fontWeight(isToday ? .bold : .regular)
                            
                            if sessions > 0 {
                                Circle()
                                    .fill(sessionColor(count: sessions))
                                    .frame(width: 6, height: 6)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .frame(height: 32)
                        .frame(maxWidth: .infinity)
                        .background(isToday ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                        .onTapGesture {
                            selectedDate = day
                        }
                    } else {
                        Text("")
                            .frame(height: 32)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            
            Divider()
            
            let selectedSessions = timerState.sessionHistory.sessions(for: selectedDate)
            let tagBreakdown = timerState.sessionHistory.sessionsByTag(for: selectedDate)
            let focusMinutes = selectedSessions * timerState.workMinutes
            
            VStack(spacing: 4) {
                Text(dateString(from: selectedDate))
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(selectedSessions) sessions • \(timerState.sessionHistory.formatFocusTime(minutes: focusMinutes))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !tagBreakdown.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(tagBreakdown, id: \.tag) { session in
                            if let tag = timerState.sessionHistory.getTag(byName: session.tag) {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 6, height: 6)
                                    Text("\(session.count)")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            HStack(spacing: 12) {
                legendItem(color: .green.opacity(0.6), text: "1-2")
                legendItem(color: .orange.opacity(0.7), text: "3-4")
                legendItem(color: .red.opacity(0.8), text: "5+")
            }
            .font(.caption2)
            
            Button("← Back") {
                showCalendar = false
                showHistory = true
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }
    
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
                        .onChange(of: timerState.workMinutes) { _, _ in
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
                        .onChange(of: timerState.shortBreakMinutes) { _, _ in
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
                        .onChange(of: timerState.longBreakMinutes) { _, _ in
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
                    .onChange(of: launchAtLogin) { _, newValue in
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

// MARK: - Pie Slice Shape
struct PieSlice: Shape {
    var progress: Double
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        let startAngle = Angle(degrees: -90)
        let endAngle = Angle(degrees: -90 + (360 * progress))
        
        path.move(to: center)
        path.addArc(center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false)
        path.closeSubpath()
        
        return path
    }
}
