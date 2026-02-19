import AppKit
import Foundation
import UserNotifications

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.contains("-help") || arguments.contains("--help") {
    print("Usage: terminal-notifier-modern -title <title> -message <message> [options]")
    print("")
    print("  -title          Notification title (required)")
    print("  -message        Notification body (required)")
    print("  -subtitle       Notification subtitle (e.g. branch and folder)")
    print("  -activate       Bundle ID of app to activate on click")
    print("  -execute        Shell command to run on click")
    print("  -group          Group ID (replaces notifications with same group)")
    print("  -threadID       Thread ID for grouping notifications in a stack")
    print("  -timeSensitive  Mark as time-sensitive (breaks through Focus Mode)")
    print("  -nosound        Suppress notification sound")
    exit(ExitCode.success)
} else if ArgumentParser.isSendMode(arguments) {
    runSendMode(arguments: arguments)
} else {
    runCallbackMode()
}

// MARK: - Send Mode

func runSendMode(arguments: [String]) {
    let config: NotificationConfig
    do {
        config = try ArgumentParser.parse(arguments)
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(ExitCode.invalidArgs)
    }

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    // Register notification category with actions before sending
    NotificationCategory.register()

    // Schedule all async work on the main queue — no data races
    DispatchQueue.main.async {
        checkAuthAndSend(config: config)
    }

    // Run event loop (processes main queue dispatches + RunLoop sources)
    app.run()
}

func checkAuthAndSend(config: NotificationConfig) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
        DispatchQueue.main.async {
            handleAuthStatus(settings.authorizationStatus, config: config)
        }
    }
}

func handleAuthStatus(_ status: UNAuthorizationStatus, config: NotificationConfig) {
    if status == .notDetermined {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                let newStatus: UNAuthorizationStatus = granted ? .authorized : .denied
                sendNotification(config: config, authStatus: newStatus)
            }
        }
    } else {
        sendNotification(config: config, authStatus: status)
    }
}

func sendNotification(config: NotificationConfig, authStatus: UNAuthorizationStatus) {
    let service: NotificationSending
    if authStatus == .authorized || authStatus == .provisional {
        service = UNNotificationService()
    } else {
        service = OsascriptNotificationService()
    }

    service.send(config: config) { result in
        DispatchQueue.main.async {
            switch result {
            case .success:
                // Small delay for delivery, then exit
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    exit(ExitCode.success)
                }
            case .failure(let error):
                fputs("Error: \(error)\n", stderr)
                exit(ExitCode.failed)
            }
        }
    }
}

// MARK: - Callback Mode

func runCallbackMode() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    let appDelegate = AppDelegate()
    app.delegate = appDelegate
    UNUserNotificationCenter.current().delegate = appDelegate

    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        NSApplication.shared.terminate(nil)
    }

    withExtendedLifetime(appDelegate) {
        app.run()
    }
}
