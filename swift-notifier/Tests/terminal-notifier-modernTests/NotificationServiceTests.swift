import XCTest
@testable import terminal_notifier_modern

final class NotificationServiceTests: XCTestCase {

    func testNotificationConfigCreation() {
        let config = NotificationConfig(
            title: "Test Title",
            message: "Test Message",
            action: .activate(bundleID: "com.apple.Terminal"),
            group: "test-group"
        )

        XCTAssertEqual(config.title, "Test Title")
        XCTAssertEqual(config.message, "Test Message")
        XCTAssertEqual(config.action, .activate(bundleID: "com.apple.Terminal"))
        XCTAssertEqual(config.group, "test-group")
    }

    func testNotificationConfigWithNilGroup() {
        let config = NotificationConfig(
            title: "Test",
            message: "Body",
            action: .none,
            group: nil
        )

        XCTAssertNil(config.group)
        XCTAssertEqual(config.action, .none)
    }

    func testExitCodes() {
        XCTAssertEqual(ExitCode.success, 0)
        XCTAssertEqual(ExitCode.invalidArgs, 1)
        XCTAssertEqual(ExitCode.permissionDenied, 2)
        XCTAssertEqual(ExitCode.failed, 3)
    }

    func testActionToJSONForUserInfo() {
        let action = ClickAction.activate(bundleID: "com.apple.Terminal")
        let json = action.toJSON()

        XCTAssertNotNil(json, "Action should produce valid JSON for userInfo storage")

        let decoded = ClickAction.fromJSON(json!)
        XCTAssertEqual(decoded, action, "Round-trip through JSON should preserve the action")
    }
}
