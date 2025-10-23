import Foundation

public struct GeorgianScriptDetector {
    @inline(__always)
    private static func isGeorgianScalar(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return (0x10A0...0x10FF).contains(v) || // Georgian (Mkhedruli/Asomtavruli)
               (0x2D00...0x2D2F).contains(v) || // Georgian Supplement
               (0x1C90...0x1CBF).contains(v)    // Georgian Extended
    }

    public static func containsGeorgian(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if isGeorgianScalar(scalar) { return true }
        }
        return false
    }

    public static func isGeorgian(_ character: Character) -> Bool {
        for scalar in character.unicodeScalars {
            if isGeorgianScalar(scalar) { return true }
        }
        return false
    }
}
