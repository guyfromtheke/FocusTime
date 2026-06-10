import SwiftUI

extension ContentView {
    // MARK: - Notion Settings View
    var notionSettingsView: some View {
        VStack(spacing: 12) {
            Text("Notion Integration")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable Sync", isOn: $notionSyncEnabled)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .onChange(of: notionSyncEnabled) { newValue in
                        NotionConfig.syncEnabled = newValue
                        if newValue && notionApiKey.isEmpty {
                            notionApiKey = NotionConfig.apiKey
                        }
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Token")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    SecureField("secret_...", text: $notionApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onChange(of: notionApiKey) { newValue in
                            NotionConfig.apiKey = newValue
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("FocusTime Database ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Required", text: $notionDatabaseId)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onChange(of: notionDatabaseId) { newValue in
                            NotionConfig.databaseId = newValue
                            notionDatabaseId = NotionConfig.databaseId
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Road to Mastery Database ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Optional", text: $notionRoadToMasteryDatabaseId)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onChange(of: notionRoadToMasteryDatabaseId) { newValue in
                            NotionConfig.roadToMasteryDatabaseId = newValue
                            notionRoadToMasteryDatabaseId = NotionConfig.roadToMasteryDatabaseId
                        }
                }
                
                HStack {
                    Button("Test Connection") {
                        testNotionConnection()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .disabled(!NotionConfig.isConfigured || isTestingConnection)
                    
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
                
                if timerState.sessionHistory.pendingNotionSyncDates.count > 0 {
                    HStack {
                        Text("\(timerState.sessionHistory.pendingNotionSyncDates.count) day(s) waiting to retry")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Button("Retry") {
                            timerState.sessionHistory.retryPendingNotionSyncs()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption2)
                        .disabled(!NotionConfig.isConfigured || !NotionConfig.syncEnabled)
                    }
                }
                
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
                Text("4. Paste the database ID and share it with the integration")
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
        .onAppear {
            if NotionConfig.syncEnabled {
                notionApiKey = NotionConfig.apiKey
            }
        }
    }
    
}
