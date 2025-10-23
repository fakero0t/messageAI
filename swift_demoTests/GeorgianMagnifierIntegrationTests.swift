import XCTest
@testable import swift_demo
import SwiftUI

final class GeorgianMagnifierIntegrationTests: XCTestCase {
    func testOverlayInstantiation() {
        let view = GeorgianMagnifierOverlay(text: "გამარჯობა") {
            Text("გამარჯობა")
        }
        XCTAssertNotNil(view)
    }
}
