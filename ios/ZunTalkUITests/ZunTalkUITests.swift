//
//  ZunTalkUITests.swift
//  ZunTalkUITests
//
//  Created by jumpei ono on 2025/07/24.
//

import XCTest

final class ZunTalkUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()

        print("🧪 [UITest] Starting app launch...")
        let launchStart = Date()
        app.launch()
        let launchTime = Date().timeIntervalSince(launchStart)
        print("🧪 [UITest] App launched in \(launchTime) seconds")

        // アプリが起動したことを確認
        print("🧪 [UITest] Waiting for app to be running...")
        let appRunning = app.wait(for: .runningForeground, timeout: 5)
        print("🧪 [UITest] App running: \(appRunning)")

        // 起動画面の要素を待つ
        print("🧪 [UITest] Looking for UI elements...")
        sleep(2) // 少し待機

        // アプリの状態をダンプ
        print("🧪 [UITest] App state: \(app.state.rawValue)")
        print("🧪 [UITest] Descendants count: \(app.descendants(matching: .any).count)")

        // 基本的なアサーション
        XCTAssertTrue(appRunning, "App should be running in foreground")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testLaunchWithoutNetwork() throws {
        // ネットワーク呼び出しをスキップしてテスト
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING", "SKIP-API-CALLS"]

        print("🧪 [UITest-NoNetwork] Starting app launch with SKIP-API-CALLS...")
        let launchStart = Date()
        app.launch()
        let launchTime = Date().timeIntervalSince(launchStart)
        print("🧪 [UITest-NoNetwork] App launched in \(launchTime) seconds")

        let appRunning = app.wait(for: .runningForeground, timeout: 5)
        print("🧪 [UITest-NoNetwork] App running: \(appRunning)")

        XCTAssertTrue(appRunning, "App should be running without network calls")
    }
}
