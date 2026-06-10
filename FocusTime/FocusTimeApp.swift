//
//  FocusTimeApp.swift
//  FocusTime
//
//  Created by Duncan Njoroge on 25/01/2026.
//

import SwiftUI
import Combine
import Carbon.HIToolbox
import UserNotifications

// MARK: - Shared Defaults Keys
enum FocusTimeDefaults {
    static let suiteName = "guyfromtheke.FocusTime"
    
    static let terminalCommand = "terminalCommand"
    static let terminalCommandID = "terminalCommandID"
    static let terminalCommandIssuedAt = "terminalCommandIssuedAt"
    static let terminalLastCommandID = "terminalLastCommandID"
    static let terminalLastCommandStatus = "terminalLastCommandStatus"
    static let terminalLastCommandHandledAt = "terminalLastCommandHandledAt"
    
    static let runtimeMode = "runtimeMode"
    static let runtimeIsRunning = "runtimeIsRunning"
    static let runtimeTimeRemaining = "runtimeTimeRemaining"
    static let runtimeTodaySessions = "runtimeTodaySessions"
    static let runtimeDailyGoal = "runtimeDailyGoal"
    static let runtimeUpdatedAt = "runtimeUpdatedAt"
}

// MARK: - Timer Mode Enum
enum TimerMode: String {
    case work = "Work"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
}

// MARK: - Timer State
class TimerState: ObservableObject {
    @Published var timeRemaining: Int {
        didSet { saveRuntimeStatus() }
    }
    @Published var isRunning = false {
        didSet { saveRuntimeStatus() }
    }
    @Published var mode: TimerMode = .work {
        didSet { saveRuntimeStatus() }
    }
    @Published var showTagPicker = false
    
    let sessionHistory = SessionHistory()
    
    @Published var workMinutes: Int {
        didSet {
            UserDefaults.standard.set(workMinutes, forKey: "workMinutes")
            sessionHistory.workMinutes = workMinutes
        }
    }
    
    @Published var shortBreakMinutes: Int {
        didSet {
            UserDefaults.standard.set(shortBreakMinutes, forKey: "shortBreakMinutes")
        }
    }
    
    @Published var longBreakMinutes: Int {
        didSet {
            UserDefaults.standard.set(longBreakMinutes, forKey: "longBreakMinutes")
        }
    }
    
    @Published var dailyGoal: Int {
        didSet {
            UserDefaults.standard.set(dailyGoal, forKey: "dailyGoal")
            saveRuntimeStatus()
        }
    }
    
    var workDuration: Int { workMinutes * 60 }
    var shortBreakDuration: Int { shortBreakMinutes * 60 }
    var longBreakDuration: Int { longBreakMinutes * 60 }
    
    let sessionsBeforeLongBreak = 4
    let totalSessionsGoal = 4
    
    init() {
        let savedWorkMinutes = UserDefaults.standard.integer(forKey: "workMinutes")
        let savedShortBreakMinutes = UserDefaults.standard.integer(forKey: "shortBreakMinutes")
        let savedLongBreakMinutes = UserDefaults.standard.integer(forKey: "longBreakMinutes")
        let savedDailyGoal = UserDefaults.standard.integer(forKey: "dailyGoal")
        
        self.workMinutes = savedWorkMinutes > 0 ? savedWorkMinutes : 25
        self.shortBreakMinutes = savedShortBreakMinutes > 0 ? savedShortBreakMinutes : 5
        self.longBreakMinutes = savedLongBreakMinutes > 0 ? savedLongBreakMinutes : 15
        self.dailyGoal = savedDailyGoal > 0 ? savedDailyGoal : 4
        self.timeRemaining = (savedWorkMinutes > 0 ? savedWorkMinutes : 25) * 60
        
        // Set workMinutes on sessionHistory for Notion sync
        sessionHistory.workMinutes = self.workMinutes
        saveRuntimeStatus()
        sessionHistory.retryPendingNotionSyncs()
        
        // Listen for day changes to refresh UI at midnight
        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Force UI refresh by triggering objectWillChange
            self?.objectWillChange.send()
        }
    }
    
    func todaySessions() -> Int {
        return sessionHistory.todaySessions()
    }
    
    func shouldTakeLongBreak() -> Bool {
        let today = todaySessions()
        return today > 0 && today % sessionsBeforeLongBreak == 0
    }
    
    func currentModeDuration() -> Int {
        switch mode {
        case .work:
            return workDuration
        case .shortBreak:
            return shortBreakDuration
        case .longBreak:
            return longBreakDuration
        }
    }
    
    func progress() -> Double {
        let total = currentModeDuration()
        guard total > 0 else { return 0 }
        return 1.0 - (Double(timeRemaining) / Double(total))
    }
    
    func completeSession(tag: String) {
        sessionHistory.addSession(tag: tag)
    }
    
    func dailyGoalProgress() -> Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(todaySessions()) / Double(dailyGoal), 1.0)
    }
    
    func dailyGoalReached() -> Bool {
        return todaySessions() >= dailyGoal
    }
    
    func saveRuntimeStatus() {
        let defaults = UserDefaults.standard
        defaults.set(mode.rawValue, forKey: FocusTimeDefaults.runtimeMode)
        defaults.set(isRunning, forKey: FocusTimeDefaults.runtimeIsRunning)
        defaults.set(timeRemaining, forKey: FocusTimeDefaults.runtimeTimeRemaining)
        defaults.set(todaySessions(), forKey: FocusTimeDefaults.runtimeTodaySessions)
        defaults.set(dailyGoal, forKey: FocusTimeDefaults.runtimeDailyGoal)
        defaults.set(Date().timeIntervalSince1970, forKey: FocusTimeDefaults.runtimeUpdatedAt)
    }
}

// MARK: - Focus Mode Manager
class FocusModeManager {
    
    static func enableFocus() {
        let task = Process()
        task.launchPath = "/usr/bin/shortcuts"
        task.arguments = ["run", "Start Focus"]
        
        do {
            try task.run()
        } catch {
            print("Focus mode shortcut not found. Using fallback.")
            enableFocusViaAppleScript()
        }
    }
    
    static func disableFocus() {
        let task = Process()
        task.launchPath = "/usr/bin/shortcuts"
        task.arguments = ["run", "Stop Focus"]
        
        do {
            try task.run()
        } catch {
            print("Focus mode shortcut not found. Using fallback.")
            disableFocusViaAppleScript()
        }
    }
    
    private static func enableFocusViaAppleScript() {
        let script = """
        do shell script "defaults -currentHost write com.apple.notificationcenterui doNotDisturb -boolean true && killall NotificationCenter 2>/dev/null || true"
        """
        runAppleScript(script)
    }
    
    private static func disableFocusViaAppleScript() {
        let script = """
        do shell script "defaults -currentHost write com.apple.notificationcenterui doNotDisturb -boolean false && killall NotificationCenter 2>/dev/null || true"
        """
        runAppleScript(script)
    }
    
    private static func runAppleScript(_ source: String) {
        guard let script = NSAppleScript(source: source) else { return }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error = error {
            print("AppleScript error: \(error)")
        }
    }
}

// MARK: - Global Hotkey Manager
class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private let callback: () -> Void
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
        registerHotkey()
    }
    
    deinit {
        unregisterHotkey()
    }
    
    private func registerHotkey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x464F4355)
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        let handlerCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.callback()
            return noErr
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            handlerCallback,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        
        RegisterEventHotKey(
            UInt32(kVK_ANSI_F),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
    }
    
    private func unregisterHotkey() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}

// MARK: - Terminal Command Bridge
class TerminalCommandCenter {
    static let shared = TerminalCommandCenter()
    
    var handler: ((String) -> Bool)?
    
    private init() {}
    
    func configure(handler: @escaping (String) -> Bool) {
        self.handler = handler
        processPendingCommand()
    }
    
    func processPendingCommand() {
        let defaults = UserDefaults.standard
        guard let command = defaults.string(forKey: FocusTimeDefaults.terminalCommand),
              let commandID = defaults.string(forKey: FocusTimeDefaults.terminalCommandID),
              !command.isEmpty else {
            return
        }
        
        if defaults.string(forKey: FocusTimeDefaults.terminalLastCommandID) == commandID {
            defaults.removeObject(forKey: FocusTimeDefaults.terminalCommand)
            return
        }
        
        guard let handler = handler else {
            return
        }
        
        let handled = handler(command)
        defaults.set(commandID, forKey: FocusTimeDefaults.terminalLastCommandID)
        defaults.set(handled ? "handled \(command)" : "unknown command \(command)", forKey: FocusTimeDefaults.terminalLastCommandStatus)
        defaults.set(Date().timeIntervalSince1970, forKey: FocusTimeDefaults.terminalLastCommandHandledAt)
        defaults.removeObject(forKey: FocusTimeDefaults.terminalCommand)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var hotkeyManager: HotkeyManager?
    var toggleCallback: (() -> Void)?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let callback = toggleCallback {
            hotkeyManager = HotkeyManager(callback: callback)
        }
        TerminalCommandCenter.shared.processPendingCommand()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        TerminalCommandCenter.shared.processPendingCommand()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        TerminalCommandCenter.shared.processPendingCommand()
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if UserDefaults.standard.bool(forKey: "focusModeEnabled") {
            FocusModeManager.disableFocus()
        }
    }
}

// MARK: - App Entry Point
@main
struct FocusTimeApp: App {
    @StateObject private var timerState = TimerState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var timer: Timer?
    @AppStorage("focusModeEnabled") private var focusModeEnabled = true
    
    var body: some Scene {
        let _ = configureTerminalCommands()
        
        MenuBarExtra {
            ContentView(
                timerState: timerState,
                onStartPause: toggleTimer,
                onReset: resetTimer,
                onSwitchMode: switchMode,
                onTagSelected: completeSessionWithTag
            )
            .onAppear {
                appDelegate.toggleCallback = toggleTimer
                if appDelegate.hotkeyManager == nil {
                    appDelegate.hotkeyManager = HotkeyManager(callback: toggleTimer)
                }
            }
        } label: {
            if timerState.isRunning {
                Text(formatTime(timerState.timeRemaining))
                    .monospacedDigit()
                    .foregroundColor(menuBarColor)
            } else {
                Image(systemName: "timer")
            }
        }
        .menuBarExtraStyle(.window)
    }
    
    var menuBarColor: Color {
        switch timerState.mode {
        case .work:
            return .red
        case .shortBreak:
            return .green
        case .longBreak:
            return .blue
        }
    }
    
    func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Timer Control Functions
    
    func configureTerminalCommands() -> Bool {
        TerminalCommandCenter.shared.configure(handler: handleTerminalCommand)
        timerState.saveRuntimeStatus()
        return true
    }
    
    func handleTerminalCommand(_ command: String) -> Bool {
        switch command {
        case "start":
            if !timerState.isRunning {
                startTimer()
            }
        case "pause":
            if timerState.isRunning {
                pauseTimer()
            }
        case "toggle":
            toggleTimer()
        case "reset":
            resetTimer()
        case "switch":
            switchMode()
        case "open":
            NSApplication.shared.activate(ignoringOtherApps: true)
        default:
            return false
        }
        
        timerState.saveRuntimeStatus()
        return true
    }
    
    func toggleTimer() {
        if timerState.isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }
    
    func startTimer() {
        guard !timerState.isRunning else { return }
        timerState.isRunning = true
        
        if timerState.mode == .work && focusModeEnabled {
            FocusModeManager.enableFocus()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timerState.timeRemaining > 0 {
                timerState.timeRemaining -= 1
            } else {
                pauseTimer()
                
                if timerState.mode == .work {
                    timerState.showTagPicker = true
                }
                
                NSSound(named: "Glass")?.play()
                sendNotification()
                
                if timerState.mode != .work {
                    switchMode()
                }
            }
        }
    }
    
    func pauseTimer() {
        guard timerState.isRunning || timer != nil else {
            timerState.saveRuntimeStatus()
            return
        }
        
        timerState.isRunning = false
        timer?.invalidate()
        timer = nil
        
        if timerState.mode == .work && focusModeEnabled {
            FocusModeManager.disableFocus()
        }
    }
    
    func resetTimer() {
        if timerState.isRunning && timerState.mode == .work && focusModeEnabled {
            FocusModeManager.disableFocus()
        }
        
        pauseTimer()
        timerState.timeRemaining = timerState.currentModeDuration()
        timerState.saveRuntimeStatus()
    }
    
    func switchMode() {
        pauseTimer()
        
        if timerState.mode == .work {
            if timerState.shouldTakeLongBreak() {
                timerState.mode = .longBreak
                timerState.timeRemaining = timerState.longBreakDuration
            } else {
                timerState.mode = .shortBreak
                timerState.timeRemaining = timerState.shortBreakDuration
            }
        } else {
            timerState.mode = .work
            timerState.timeRemaining = timerState.workDuration
        }
        
        timerState.saveRuntimeStatus()
    }
    
    func completeSessionWithTag(_ tag: String) {
        timerState.completeSession(tag: tag)
        timerState.showTagPicker = false
        switchMode()
        timerState.saveRuntimeStatus()
    }
    
    func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "FocusTime"
        
        if timerState.mode == .work && timerState.todaySessions() + 1 == timerState.dailyGoal {
            content.body = "🎉 Daily goal reached! Great work!"
        } else {
            switch timerState.mode {
            case .work:
                if timerState.shouldTakeLongBreak() {
                    content.body = "Great work! You've earned a long break."
                } else {
                    content.body = "Time's up! Take a short break."
                }
            case .shortBreak, .longBreak:
                content.body = "Break over! Ready to focus?"
            }
        }
        
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
