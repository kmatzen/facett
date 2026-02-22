import XCTest
@testable import Facett

final class ErrorHandlerTests: XCTestCase {

    // MARK: - BLE Recovery Strategy

    func testRecoveryStrategyForConnectionTimeout() {
        let error = NSError(domain: "CBATTError", code: 7)
        assertStrategy(ErrorHandler.shared.getBLERecoveryStrategy(for: error), .reconnectWithBackoff)
    }

    func testRecoveryStrategyForConnectionFailed() {
        let error = NSError(domain: "CBATTError", code: 6)
        assertStrategy(ErrorHandler.shared.getBLERecoveryStrategy(for: error), .resetAndRetry)
    }

    func testRecoveryStrategyForDisconnected() {
        let error = NSError(domain: "CBATTError", code: 10)
        assertStrategy(ErrorHandler.shared.getBLERecoveryStrategy(for: error), .reconnect)
    }

    func testRecoveryStrategyForAuthInsufficient() {
        let error = NSError(domain: "CBATTError", code: 5)
        assertStrategy(ErrorHandler.shared.getBLERecoveryStrategy(for: error), .reclaimControl)
    }

    func testRecoveryStrategyForAttributeNotFound() {
        let error = NSError(domain: "CBATTError", code: 3)
        assertStrategy(ErrorHandler.shared.getBLERecoveryStrategy(for: error), .rediscoverServices)
    }

    func testRecoveryStrategyForReadNotPermitted() {
        let error = NSError(domain: "CBATTError", code: 2)
        assertStrategy(ErrorHandler.shared.getBLERecoveryStrategy(for: error), .checkPermissions)
    }

    func testRecoveryStrategyForUnknownError() {
        let error = NSError(domain: "CBATTError", code: 999)
        assertStrategy(ErrorHandler.shared.getBLERecoveryStrategy(for: error), .none)
    }

    func testRecoveryStrategyForNonNSError() {
        struct CustomError: Error {}
        assertStrategy(ErrorHandler.shared.getBLERecoveryStrategy(for: CustomError()), .none)
    }

    // MARK: - BLE Recovery Strategy Descriptions

    func testAllRecoveryStrategiesHaveDescriptions() {
        let strategies: [BLERecoveryStrategy] = [
            .none, .reconnect, .reconnectWithBackoff,
            .resetAndRetry, .reclaimControl, .rediscoverServices, .checkPermissions
        ]

        for strategy in strategies {
            XCTAssertFalse(strategy.description.isEmpty, "\(strategy) should have a description")
        }
    }

    // MARK: - Execute with Recovery

    func testExecuteWithRecoverySucceedsFirstAttempt() async throws {
        let result: Int = try await ErrorHandler.shared.executeWithRecovery(
            operation: "test", maxAttempts: 3, delay: 0.01
        ) {
            return 42 as Int
        }

        XCTAssertEqual(result, 42)
    }
}

private func assertStrategy(_ actual: BLERecoveryStrategy, _ expected: BLERecoveryStrategy, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(actual.description, expected.description, file: file, line: line)
}
