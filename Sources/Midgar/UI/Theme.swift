import SwiftUI

extension Color {
    /// Creates a color from a `#RRGGBB` or `#RRGGBBAA` hex string. Returns `nil` for malformed input.
    init?(hex: String?) {
        guard let components = midgarRGBA(hex: hex) else { return nil }
        self.init(.sRGB, red: components.r, green: components.g, blue: components.b, opacity: components.a)
    }
}

/// Parses a hex color string into sRGB components in `0...1`. Internal so it can be unit-tested
/// without comparing opaque `Color` values.
func midgarRGBA(hex: String?) -> (r: Double, g: Double, b: Double, a: Double)? {
    guard var string = hex?.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased(),
          string.count == 6 || string.count == 8,
          string.allSatisfy({ $0.isHexDigit })
    else { return nil }

    if string.count == 6 { string += "FF" }
    guard let value = UInt32(string, radix: 16) else { return nil }
    return (
        r: Double((value >> 24) & 0xFF) / 255,
        g: Double((value >> 16) & 0xFF) / 255,
        b: Double((value >> 8) & 0xFF) / 255,
        a: Double(value & 0xFF) / 255
    )
}
