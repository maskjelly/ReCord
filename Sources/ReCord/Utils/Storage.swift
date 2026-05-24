import Foundation

enum ReCordStorage {
    private static let recordingDirectoryKey = "recordingDirectoryPath"

    static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ReCord", isDirectory: true)
    }

    static var recordingsDirectory: URL {
        if let path = UserDefaults.standard.string(forKey: recordingDirectoryKey), !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
        return (movies ?? applicationSupportDirectory).appendingPathComponent("ReCord Recordings", isDirectory: true)
    }

    static var configuredRecordingDirectory: URL? {
        guard let path = UserDefaults.standard.string(forKey: recordingDirectoryKey), !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func setRecordingsDirectory(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: recordingDirectoryKey)
    }

    static var sessionsIndexURL: URL {
        applicationSupportDirectory.appendingPathComponent("sessions.json")
    }

    static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
    }

    static func saveSessions(_ sessions: [RecordingSession]) throws {
        try ensureDirectories()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(sessions).write(to: sessionsIndexURL, options: .atomic)
    }

    static func loadSessions() -> [RecordingSession] {
        guard FileManager.default.fileExists(atPath: sessionsIndexURL.path) else { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([RecordingSession].self, from: Data(contentsOf: sessionsIndexURL))
        } catch {
            return []
        }
    }
}
