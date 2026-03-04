//
//  HeatmapView.swift
//  FocusTime
//
//  Created by Duncan Njoroge on 05/02/2026.
//

import SwiftUI

// MARK: - Heatmap View
struct HeatmapView: View {
    @ObservedObject var timerState: TimerState
    @Binding var isPresented: Bool
    
    @State private var selectedYear: Int
    @State private var selectedDate: Date? = nil
    
    private let cellSize: CGFloat = 8
    private let cellSpacing: CGFloat = 2
    
    init(timerState: TimerState, isPresented: Binding<Bool>) {
        self.timerState = timerState
        self._isPresented = isPresented
        self._selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Activity")
                .font(.headline)
            
            HStack {
                Button("◀") {
                    selectedYear -= 1
                    selectedDate = nil
                }
                .buttonStyle(.borderless)
                .disabled(selectedYear <= 2020)
                
                Spacer()
                
                Text(String(selectedYear))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("▶") {
                    selectedYear += 1
                    selectedDate = nil
                }
                .buttonStyle(.borderless)
                .disabled(selectedYear >= Calendar.current.component(.year, from: Date()))
            }
            .padding(.horizontal, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("")
                            .frame(width: 24)
                        
                        ForEach(0..<12, id: \.self) { month in
                            Text(monthAbbrev(month))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .frame(width: weeksInMonth(month) * (cellSize + cellSpacing), alignment: .leading)
                        }
                    }
                    
                    HStack(alignment: .top, spacing: 0) {
                        VStack(alignment: .trailing, spacing: cellSpacing) {
                            Text("")
                                .font(.system(size: 8))
                                .frame(height: cellSize)
                            Text("Mon")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .frame(height: cellSize)
                            Text("")
                                .font(.system(size: 8))
                                .frame(height: cellSize)
                            Text("Wed")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .frame(height: cellSize)
                            Text("")
                                .font(.system(size: 8))
                                .frame(height: cellSize)
                            Text("Fri")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .frame(height: cellSize)
                            Text("")
                                .font(.system(size: 8))
                                .frame(height: cellSize)
                        }
                        .frame(width: 24)
                        
                        HStack(spacing: cellSpacing) {
                            ForEach(getAllWeeks(), id: \.self) { weekStart in
                                VStack(spacing: cellSpacing) {
                                    ForEach(0..<7, id: \.self) { dayOffset in
                                        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart)!
                                        let isInYear = Calendar.current.component(.year, from: date) == selectedYear
                                        let isFuture = date > Date()
                                        
                                        if isInYear && !isFuture {
                                            let sessions = timerState.sessionHistory.sessions(for: date)
                                            let isSelected = selectedDate != nil && Calendar.current.isDate(date, inSameDayAs: selectedDate!)
                                            let isToday = Calendar.current.isDateInToday(date)
                                            
                                            Rectangle()
                                                .fill(colorForSessions(sessions))
                                                .frame(width: cellSize, height: cellSize)
                                                .cornerRadius(2)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .stroke(isSelected ? Color.white : (isToday ? Color.accentColor : Color.clear), lineWidth: 1)
                                                )
                                                .onTapGesture {
                                                    selectedDate = date
                                                }
                                        } else {
                                            Rectangle()
                                                .fill(Color.clear)
                                                .frame(width: cellSize, height: cellSize)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            
            HStack(spacing: 4) {
                Text("Less")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                
                ForEach([0, 1, 3, 5, 7], id: \.self) { level in
                    Rectangle()
                        .fill(colorForSessions(level))
                        .frame(width: 10, height: 10)
                        .cornerRadius(2)
                }
                
                Text("More")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            if let date = selectedDate {
                selectedDateInfo(for: date)
            } else {
                yearSummary
            }
            
            Button("← Back") {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }
    
    // MARK: - Get All Weeks in Year
    
    func getAllWeeks() -> [Date] {
        let calendar = Calendar.current
        
        var components = DateComponents()
        components.year = selectedYear
        components.month = 1
        components.day = 1
        
        guard let jan1 = calendar.date(from: components) else { return [] }
        
        let jan1Weekday = calendar.component(.weekday, from: jan1)
        let daysToSubtract = (jan1Weekday + 5) % 7
        let firstMonday = calendar.date(byAdding: .day, value: -daysToSubtract, to: jan1)!
        
        var weeks: [Date] = []
        var currentMonday = firstMonday
        
        for _ in 0..<53 {
            weeks.append(currentMonday)
            currentMonday = calendar.date(byAdding: .day, value: 7, to: currentMonday)!
            
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: currentMonday)!
            if calendar.component(.year, from: endOfWeek) > selectedYear &&
               calendar.component(.year, from: currentMonday) > selectedYear {
                break
            }
        }
        
        return weeks
    }
    
    // MARK: - Month Helpers
    
    func monthAbbrev(_ month: Int) -> String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return months[month]
    }
    
    func weeksInMonth(_ month: Int) -> CGFloat {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = selectedYear
        components.month = month + 1
        components.day = 1
        
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return 4
        }
        
        let days = range.count
        return CGFloat(days) / 7.0 * (cellSize + cellSpacing)
    }
    
    // MARK: - Selected Date Info
    
    func selectedDateInfo(for date: Date) -> some View {
        let sessions = timerState.sessionHistory.sessions(for: date)
        let focusMinutes = sessions * timerState.workMinutes
        let isToday = Calendar.current.isDateInToday(date)
        
        return VStack(spacing: 4) {
            Text(formatDate(date))
                .font(.caption)
                .fontWeight(.medium)
            
            HStack(spacing: 16) {
                VStack {
                    Text("\(sessions)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(sessions > 0 ? .primary : .secondary)
                    Text("sessions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(timerState.sessionHistory.formatFocusTime(minutes: focusMinutes))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(sessions > 0 ? .primary : .secondary)
                    Text("focus time")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if isToday && !timerState.dailyGoalReached() {
                Text("\(timerState.dailyGoal - timerState.todaySessions()) more to reach today's goal")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            
            Button("Clear selection") {
                selectedDate = nil
            }
            .buttonStyle(.borderless)
            .font(.caption2)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Year Summary
    
    var yearSummary: some View {
        let stats = getYearStats()
        
        return VStack(spacing: 8) {
            HStack(spacing: 16) {
                VStack {
                    Text("\(stats.totalSessions)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("sessions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(stats.activeDays)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("active days")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(timerState.sessionHistory.formatFocusTime(minutes: stats.totalSessions * timerState.workMinutes))
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("total focus")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Tap any day to see details")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Functions
    
    func colorForSessions(_ count: Int) -> Color {
        switch count {
        case 0:
            return Color.gray.opacity(0.2)
        case 1...2:
            return Color.green.opacity(0.4)
        case 3...4:
            return Color.green.opacity(0.6)
        case 5...6:
            return Color.green.opacity(0.8)
        default:
            return Color.green
        }
    }
    
    func getYearStats() -> (totalSessions: Int, activeDays: Int) {
        let calendar = Calendar.current
        var totalSessions = 0
        var activeDays = 0
        
        for (dateString, dayData) in timerState.sessionHistory.history {
            if let date = timerState.sessionHistory.dateFromKey(dateString) {
                let year = calendar.component(.year, from: date)
                if year == selectedYear {
                    let dayCount = dayData.reduce(0) { $0 + $1.count }
                    totalSessions += dayCount
                    if dayCount > 0 {
                        activeDays += 1
                    }
                }
            }
        }
        
        return (totalSessions, activeDays)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
}
