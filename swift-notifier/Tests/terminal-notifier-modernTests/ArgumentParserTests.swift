import XCTest
@testable import terminal_notifier_modern

final class ArgumentParserTests: XCTestCase {

    func testParseValidArgs() throws {
        let config = try ArgumentParser.parse([
            "-title", "Hello",
            "-message", "World",
            "-activate", "com.apple.Terminal",
            "-group", "test-group"
        ])

        XCTAssertEqual(config.title, "Hello")
        XCTAssertEqual(config.message, "World")
        XCTAssertEqual(config.action, .activate(bundleID: "com.apple.Terminal"))
        XCTAssertEqual(config.group, "test-group")
    }

    func testParseMinimalArgs() throws {
        let config = try ArgumentParser.parse([
            "-title", "Hello",
            "-message", "World"
        ])

        XCTAssertEqual(config.title, "Hello")
        XCTAssertEqual(config.message, "World")
        XCTAssertEqual(config.action, .none)
        XCTAssertNil(config.group)
    }

    func testParseMissingTitle() {
        XCTAssertThrowsError(try ArgumentParser.parse([
            "-message", "World"
        ])) { error in
            XCTAssertTrue(error is ArgumentParserError)
            if case ArgumentParserError.missingTitle = error {
                // OK
            } else {
                XCTFail("Expected missingTitle error, got \(error)")
            }
        }
    }

    func testParseMissingMessage() {
        XCTAssertThrowsError(try ArgumentParser.parse([
            "-title", "Hello"
        ])) { error in
            XCTAssertTrue(error is ArgumentParserError)
            if case ArgumentParserError.missingMessage = error {
                // OK
            } else {
                XCTFail("Expected missingMessage error, got \(error)")
            }
        }
    }

    func testParseMissingValue() {
        XCTAssertThrowsError(try ArgumentParser.parse([
            "-title"
        ])) { error in
            XCTAssertTrue(error is ArgumentParserError)
            if case ArgumentParserError.missingValue(let flag) = error {
                XCTAssertEqual(flag, "-title")
            } else {
                XCTFail("Expected missingValue error, got \(error)")
            }
        }
    }

    func testParseExecuteAction() throws {
        let config = try ArgumentParser.parse([
            "-title", "Test",
            "-message", "Body",
            "-execute", "tmux select-pane -t main:0.2"
        ])

        XCTAssertEqual(config.action, .execute(command: "tmux select-pane -t main:0.2"))
    }

    func testParseBothActivateAndExecute() throws {
        let config = try ArgumentParser.parse([
            "-title", "Test",
            "-message", "Body",
            "-activate", "com.apple.Terminal",
            "-execute", "echo hello"
        ])

        XCTAssertEqual(config.action, .executeAndActivate(command: "echo hello", bundleID: "com.apple.Terminal"))
    }

    func testParseUnknownFlagsIgnored() throws {
        let config = try ArgumentParser.parse([
            "-title", "Test",
            "-message", "Body",
            "-unknown", "value"
        ])

        XCTAssertEqual(config.title, "Test")
        XCTAssertEqual(config.message, "Body")
    }

    func testIsSendMode() {
        XCTAssertTrue(ArgumentParser.isSendMode(["-title", "Hello", "-message", "World"]))
        XCTAssertFalse(ArgumentParser.isSendMode([]))
        XCTAssertFalse(ArgumentParser.isSendMode(["-message", "World"]))
    }

    func testParseGroupWithSpecialCharacters() throws {
        let config = try ArgumentParser.parse([
            "-title", "Test",
            "-message", "Body",
            "-group", "claude-notif-1234567890"
        ])

        XCTAssertEqual(config.group, "claude-notif-1234567890")
    }
}
