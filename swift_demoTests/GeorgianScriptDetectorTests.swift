import XCTest
@testable import swift_demo

final class GeorgianScriptDetectorTests: XCTestCase {

    func testContainsGeorgian_Positive() {
        // Georgian Mkhedruli letters: "გამარჯობა"
        let text = "გამარჯობა"
        XCTAssertTrue(GeorgianScriptDetector.containsGeorgian(text))
    }

    func testContainsGeorgian_Negative() {
        let text = "Hello world! 123 :)"
        XCTAssertFalse(GeorgianScriptDetector.containsGeorgian(text))
    }

    func testContainsGeorgian_Mixed() {
        let text = "Hello გამარჯობა world"
        XCTAssertTrue(GeorgianScriptDetector.containsGeorgian(text))
    }

    func testIsGeorgian_Character() {
        let char: Character = "გ"
        XCTAssertTrue(GeorgianScriptDetector.isGeorgian(char))

        let nonGeorgian: Character = "A"
        XCTAssertFalse(GeorgianScriptDetector.isGeorgian(nonGeorgian))
    }

    func testContainsGeorgian_WithEmojiAndPunctuation() {
        let text = "🙂 გამარჯობა! 👋"
        XCTAssertTrue(GeorgianScriptDetector.containsGeorgian(text))
    }
}
