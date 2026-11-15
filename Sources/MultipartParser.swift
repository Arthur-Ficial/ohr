// ============================================================================
// MultipartParser.swift - Multipart form-data parser
// Part of ohr - On-device speech-to-text from the command line
// ============================================================================

import Foundation

// MARK: - Multipart Part

/// A single part from a multipart/form-data body.
struct MultipartPart: Sendable {
    let name: String
    let filename: String?
    let contentType: String?
    let data: Data
}

// MARK: - Multipart Parser

/// Parses multipart/form-data request bodies.
enum MultipartParser {

    /// Extract the boundary string from a Content-Type header.
    /// e.g. "multipart/form-data; boundary=----WebKitFormBoundary" → "----WebKitFormBoundary"
    static func extractBoundary(from contentType: String) -> String? {
        let parts = contentType.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        for part in parts {
            if part.lowercased().hasPrefix("boundary=") {
                var boundary = String(part.dropFirst("boundary=".count))
                // Remove surrounding quotes if present
                if boundary.hasPrefix("\"") && boundary.hasSuffix("\"") && boundary.count >= 2 {
                    boundary = String(boundary.dropFirst().dropLast())
                }
                return boundary
            }
        }
        return nil
    }

    /// Parse a multipart/form-data body into parts.
    static func parse(data: Data, boundary: String) -> [MultipartPart] {
        let delimiter = "--\(boundary)".data(using: .utf8)!
        let end = "--\(boundary)--".data(using: .utf8)!
        let crlf = "\r\n".data(using: .utf8)!
        let doubleCrlf = "\r\n\r\n".data(using: .utf8)!

        var parts: [MultipartPart] = []

        // Split by delimiter
        var ranges: [Range<Data.Index>] = []
        var searchStart = data.startIndex
        while let range = data.range(of: delimiter, in: searchStart..<data.endIndex) {
            ranges.append(range)
            searchStart = range.upperBound
        }

        // Process each section between delimiters
        for i in 0..<(ranges.count - 1) {
            let sectionStart = ranges[i].upperBound
            let sectionEnd = ranges[i + 1].lowerBound

            // Check for end marker
            if sectionStart + end.count <= data.endIndex {
                let potentialEnd = data[sectionStart..<min(sectionStart + end.count, data.endIndex)]
                if potentialEnd == end[delimiter.count...] { break }
            }

            let section = data[sectionStart..<sectionEnd]

            // Skip leading CRLF
            var contentStart = section.startIndex
            if section.starts(with: crlf) {
                contentStart = section.index(contentStart, offsetBy: crlf.count)
            }

            let sectionData = data[contentStart..<sectionEnd]

            // Find headers/body separator
            guard let headerEnd = sectionData.range(of: doubleCrlf) else { continue }

            let headersData = sectionData[sectionData.startIndex..<headerEnd.lowerBound]
            let bodyData = sectionData[headerEnd.upperBound..<sectionData.endIndex]

            // Strip trailing CRLF from body
            var body = Data(bodyData)
            if body.suffix(crlf.count) == crlf {
                body = body.dropLast(crlf.count)
            }

            // Parse headers
            guard let headersString = String(data: headersData, encoding: .utf8) else { continue }
            let headers = parseHeaders(headersString)

            // Extract name and filename from Content-Disposition
            guard let disposition = headers["content-disposition"] else { continue }
            guard let name = extractParam(from: disposition, key: "name") else { continue }
            let filename = extractParam(from: disposition, key: "filename")
            let partContentType = headers["content-type"]

            parts.append(MultipartPart(
                name: name,
                filename: filename,
                contentType: partContentType,
                data: body
            ))
        }

        return parts
    }

    // MARK: - Private

    private static func parseHeaders(_ string: String) -> [String: String] {
        var headers: [String: String] = [:]
        for line in string.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        return headers
    }

    private static func extractParam(from header: String, key: String) -> String? {
        let pattern = "\(key)=\""
        guard let start = header.range(of: pattern) else { return nil }
        let afterKey = header[start.upperBound...]
        guard let end = afterKey.firstIndex(of: "\"") else { return nil }
        return String(afterKey[..<end])
    }
}
