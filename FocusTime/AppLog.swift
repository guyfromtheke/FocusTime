import OSLog

enum AppLog {
    static let app = Logger(subsystem: FocusTimeDefaults.suiteName, category: "App")
    static let notion = Logger(subsystem: FocusTimeDefaults.suiteName, category: "Notion")
}
