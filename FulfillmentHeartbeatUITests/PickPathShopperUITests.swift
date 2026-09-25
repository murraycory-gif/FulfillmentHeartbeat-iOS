import XCTest

final class PickPathShopperUITests: XCTestCase {
    func testUnitedStore22PickPathShoppers() {
        assertZeroPathNotice(store: "2224")
        assertShopperRows(store: "22")
    }

    private func assertZeroPathNotice(store: String) {
        let app = launchPickPath(store: store)
        let shoppers = app.descendants(matching: .any)["pick-path-shoppers"]
        XCTAssertTrue(shoppers.waitForExistence(timeout: 120), "Pick Path shoppers for store \(store) did not appear")
        let notice = app.staticTexts["No Path Picker rows"]
        XCTAssertTrue(notice.waitForExistence(timeout: 120), "Zero-path store \(store) should show No Path Picker rows")
        app.terminate()
    }

    private func assertShopperRows(store: String) {
        let app = launchPickPath(store: store)
        let shoppers = app.descendants(matching: .any)["pick-path-shoppers"]
        XCTAssertTrue(shoppers.waitForExistence(timeout: 120), "Pick Path shoppers for store \(store) did not appear")
        let notice = app.staticTexts["No Path Picker rows"]
        let loading = app.staticTexts["Loading shoppers…"]
        let settled = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: loading)
        wait(for: [settled], timeout: 120)
        let rows = app.descendants(matching: .any).matching(identifier: "pick-path-shopper-row")
        let appeared = expectation(for: NSPredicate(format: "count > 0"), evaluatedWith: rows)
        wait(for: [appeared], timeout: 120)
        XCTAssertFalse(notice.exists, "Store \(store) has path rows and must not show the empty notice")
        XCTAssertGreaterThan(rows.count, 0, "Store \(store) should list shopper rows")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "United-store-22-pick-path"
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
    }

    private func launchPickPath(store: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-HeartbeatPickPathStore", store]
        app.launch()
        return app
    }
}
