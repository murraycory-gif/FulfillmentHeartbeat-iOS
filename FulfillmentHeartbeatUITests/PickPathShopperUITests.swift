import XCTest

final class PickPathShopperUITests: XCTestCase {
    func testUnitedStore22PickPathShoppers() {
        let app = XCUIApplication()
        app.launchArguments += ["-HeartbeatPickPathStore", "22"]
        app.launch()
        let shoppers = app.descendants(matching: .any)["pick-path-shoppers"]
        XCTAssertTrue(shoppers.waitForExistence(timeout: 90), "Pick Path shoppers for store 22 did not appear")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "United-store-22-pick-path"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
