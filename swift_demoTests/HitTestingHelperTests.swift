import XCTest
@testable import swift_demo

final class HitTestingHelperTests: XCTestCase {

    func testCharacterIndex_SimpleSingleLine() {
        let helper = TextHitTestingHelper()
        let text = AttributedString("გამარჯობა")
        let size = CGSize(width: 300, height: 60)

        // Tap somewhere likely near the start
        let idx = helper.characterIndex(at: CGPoint(x: 5, y: 10), in: size, text: text)
        XCTAssertNotNil(idx)
        if let i = idx { XCTAssertGreaterThanOrEqual(i, 0) }
    }

    func testCharacterIndex_OutOfBounds() {
        let helper = TextHitTestingHelper()
        let text = AttributedString("გამარჯობა")
        let size = CGSize(width: 100, height: 40)

        // Far outside the view bounds
        let idx = helper.characterIndex(at: CGPoint(x: 1000, y: 1000), in: size, text: text)
        XCTAssertNil(idx)
    }
}
