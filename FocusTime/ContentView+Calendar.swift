import SwiftUI

extension ContentView {
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
    
}
