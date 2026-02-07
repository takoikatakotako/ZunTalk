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

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    /// UIテスト用のアプリインスタンスを作成（API呼び出しをスキップ）
    private func createTestApp() -> XCUIApplication {
        let app = XCUIApplication()
        // UIテスト時はAPI呼び出しをスキップしてLambdaのコールドスタート問題を回避
        app.launchArguments = ["UI-TESTING", "SKIP-API-CALLS"]
        return app
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UIテスト: アプリが正常に起動することを確認
        let app = createTestApp()
        app.launch()

        // アプリが起動したことを確認
        let appRunning = app.wait(for: .runningForeground, timeout: 5)
        XCTAssertTrue(appRunning, "App should be running in foreground")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

}
