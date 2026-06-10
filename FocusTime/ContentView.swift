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
import AppKit
import UniformTypeIdentifiers

// MARK: - Main Content View
struct ContentView: View {
    @ObservedObject var timerState: TimerState
    @StateObject var notionService = NotionService.shared
    
    var onStartPause: () -> Void
    var onReset: () -> Void
    var onSwitchMode: () -> Void
    var onTagSelected: (String) -> Void
    
    @State var showSettings = false
    @State var showHistory = false
    @State var showCalendar = false
    @State var showHeatmap = false
    @State var showTagStats = false
    @State var showTagManager = false
    @State var showNotionSettings = false
    @State var selectedDate = Date()
    @State var newTagName = ""
    @State var newTagColor = Color.blue
    @State var showEditTag = false
    @State var editingTag: SessionTag? = nil
    @State var editTagName = ""
    @State var editTagColor = Color.blue
    
    // Notion settings
    @State var notionApiKey = ""
    @State var notionDatabaseId = NotionConfig.databaseId
    @State var notionRoadToMasteryDatabaseId = NotionConfig.roadToMasteryDatabaseId
    @State var notionSyncEnabled = NotionConfig.syncEnabled
    @State var isTestingConnection = false
    @State var connectionTestResult: String?
    @State var historySyncResult: String?
    @State var backupResult: String?
    
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("soundEnabled") var soundEnabled = true
    @AppStorage("focusModeEnabled") var focusModeEnabled = true
    
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
    
}
