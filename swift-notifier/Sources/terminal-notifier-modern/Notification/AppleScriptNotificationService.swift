import Foundation

/// Notification service using osascript subprocess.
/// Always works on macOS — no permission required.
/// The notification icon will be Script Editor's icon.
final class OsascriptNotificationService: NotificationSending {

    func send(config: NotificationConfig, completion: @escaping (Result<Void, Error>) -> Void) {
        let escapedTitle = config.title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedMessage = config.message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let source = "display notification \"\(escapedMessage)\" with title \"\(escapedTitle)\""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]

        let pipe = Pipe()
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                completion(.success(()))
            } else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = String(data: errorData, encoding: .utf8) ?? "unknown error"
                completion(.failure(NSError(
                    domain: "OsascriptNotification",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: errorMsg]
                )))
            }
        } catch {
            completion(.failure(error))
        }
    }
}
