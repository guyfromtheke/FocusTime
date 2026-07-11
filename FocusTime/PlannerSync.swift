//
//  PlannerSync.swift
//  FocusTime
//
//  Created by Duncan Njoroge on 10/07/2026.
//

import Foundation
import OSLog

/// Fire-and-forget push of the full session history to the homelab Glance
/// planner. Mirrors the NotionService pattern: personal tool, endpoint and
/// token are hardcoded. The receiver (focus-sync.service on the glance
/// server) writes the payload to /opt/glance/assets/focus-data.json where
/// the planner page reads it.
final class PlannerSync {
    static let shared = PlannerSync()

    private let endpoint = URL(string: "http://192.168.100.85:8087/focus")!
    private let token = "bce599d4ed42e02fa5c201aa85e23aacd96ebaa5624ff73a"
    private let log = Logger(subsystem: FocusTimeDefaults.suiteName, category: "PlannerSync")

    private struct Payload: Codable {
        let schemaVersion: Int
        let exportedAt: Date
        let workMinutes: Int
        let history: [String: [TaggedSession]]
        let tags: [SessionTag]
    }

    func push(history: [String: [TaggedSession]], tags: [SessionTag], workMinutes: Int) {
        let payload = Payload(
            schemaVersion: 1,
            exportedAt: Date(),
            workMinutes: workMinutes,
            history: history,
            tags: tags
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let body = try? encoder.encode(payload) else {
            log.error("Failed to encode planner payload")
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Focus-Token")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [log] _, response, error in
            if let error {
                log.info("Planner sync skipped: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                log.error("Planner sync rejected: HTTP \(http.statusCode)")
            }
        }.resume()
    }
}
