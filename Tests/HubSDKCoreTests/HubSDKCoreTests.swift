import XCTest
import HubIntegrationCore
@testable import HubSDKCore

// MARK: - Mock Integrations

@MainActor
private final class MockIntegration: HubDependencyIntegration {
    static var name: String { "Mock" }
    var provider: String { "MockProvider" }
    private(set) var startCalled = false

    func start() {
        startCalled = true
    }
}

@MainActor
private final class AnotherMockIntegration: HubDependencyIntegration {
    static var name: String { "AnotherMock" }
    var provider: Int { 42 }

    func start() {}
}

@MainActor
private final class MockAwaitableIntegration: HubDependencyIntegration, AwaitableIntegration {
    static var name: String { "MockAwaitable" }
    var provider: String { "AwaitableProvider" }
    var isReady: Bool = false
    var onReady: (() -> Void)?

    func start() {}

    func simulateReady() {
        isReady = true
        onReady?()
    }
}

// MARK: - Tests

@MainActor
final class HubSDKCoreTests: XCTestCase {

    // MARK: Registration & Retrieval

    func testRegisterAndRetrieveIntegration() {
        let core = HubSDKCore()
        core.register(MockIntegration())

        XCTAssertNotNil(core.integration(ofType: MockIntegration.self))
    }

    func testRetrieveUnregisteredIntegrationReturnsNil() {
        let core = HubSDKCore()

        XCTAssertNil(core.integration(ofType: MockIntegration.self))
    }

    func testRetrieveDistinguishesBetweenTypes() {
        let core = HubSDKCore()
        core.register(MockIntegration())
        core.register(AnotherMockIntegration())

        let mock = core.integration(ofType: MockIntegration.self)
        let another = core.integration(ofType: AnotherMockIntegration.self)

        XCTAssertNotNil(mock)
        XCTAssertNotNil(another)
        XCTAssertEqual(mock?.provider, "MockProvider")
        XCTAssertEqual(another?.provider, 42)
    }

    func testMultipleRegistrationsOfSameTypeReturnsFirst() {
        let core = HubSDKCore()
        let first = MockIntegration()
        let second = MockIntegration()
        core.register(first)
        core.register(second)

        let retrieved = core.integration(ofType: MockIntegration.self)
        XCTAssertTrue(retrieved === first)
    }

    // MARK: waitUntilReady

    func testWaitUntilReadyReturnsImmediatelyWhenNothingAwaited() async {
        let core = HubSDKCore()
        core.register(MockIntegration()) // awaitReady = false (default)

        let start = Date()
        await core.waitUntilReady(timeout: 5)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 1.0, "Should return immediately when no integrations are awaited")
    }

    func testWaitUntilReadyReturnsImmediatelyWhenNoIntegrations() async {
        let core = HubSDKCore()

        let start = Date()
        await core.waitUntilReady(timeout: 5)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 1.0, "Should return immediately when no integrations registered")
    }

    func testWaitUntilReadyTimesOutWhenIntegrationNeverReady() async {
        let core = HubSDKCore()
        core.register(MockAwaitableIntegration(), awaitReady: true)

        let timeout: TimeInterval = 0.5
        let start = Date()
        await core.waitUntilReady(timeout: timeout)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertGreaterThanOrEqual(elapsed, timeout * 0.8, "Should wait close to timeout duration")
        XCTAssertLessThan(elapsed, timeout + 2.0, "Should not wait much longer than timeout")
    }
}
