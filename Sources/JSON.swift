// ============================================================================
// JSON.swift - JSON encoding helpers
// Part of ohr - On-device speech-to-text from the command line
// ============================================================================

import Foundation

/// Encode a value to a JSON string.
/// - Parameters:
///   - value: Any Encodable value
///   - pretty: If true, use pretty-printed formatting (default).
///             If false, use compact single-line format.
/// - Returns: JSON string, or "{}" if encoding fails.
func jsonString(_ value: some Encodable, pretty: Bool = true) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    if pretty { encoder.outputFormatting.insert(.prettyPrinted) }
    guard let data = try? encoder.encode(value),
          let str = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return str
}
