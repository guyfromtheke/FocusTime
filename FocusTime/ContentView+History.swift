import SwiftUI

extension ContentView {
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
    
}
