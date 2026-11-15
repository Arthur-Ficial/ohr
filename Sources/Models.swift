// ============================================================================
// Models.swift - Data types for CLI and server responses
// Part of ohr - On-device speech-to-text from the command line
// ============================================================================

import Foundation
import OhrCore

// MARK: - CLI Response Types

struct OhrResponse: Encodable {
    let model: String
    let text: String
    let segments: [OhrCore.TranscriptionSegment]?
    let duration: Double?
    let language: String?
    let metadata: Metadata
    struct Metadata: Encodable {
        let onDevice: Bool
        let version: String
        enum CodingKeys: String, CodingKey { case onDevice = "on_device"; case version }
    }
}

// MARK: - Models List

struct ModelsListResponse: Encodable, Sendable {
    let object: String
    let data: [ModelObject]

    struct ModelObject: Encodable, Sendable {
        let id: String
        let object: String
        let created: Int
        let owned_by: String
        let supported_formats: [String]
        let supported_response_formats: [String]
        let notes: String
    }
}
