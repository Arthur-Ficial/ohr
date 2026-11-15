// ============================================================================
// OpenAIModels.swift - OpenAI transcription API types
// Part of ohr - On-device speech-to-text from the command line
// ============================================================================

import Foundation

// MARK: - Response Format

/// Supported response formats for the transcription API.
public enum ResponseFormatType: String, Codable, Sendable {
    case json = "json"
    case text = "text"
    case srt = "srt"
    case verboseJSON = "verbose_json"
    case vtt = "vtt"
}

// MARK: - Transcription Response (json format)

/// Simple transcription response - matches OpenAI's `json` format.
public struct TranscriptionResponse: Encodable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

// MARK: - Verbose Transcription Response (verbose_json format)

/// Detailed transcription response with segments and timing.
public struct VerboseTranscriptionResponse: Encodable, Sendable {
    public let task: String
    public let language: String
    public let duration: Double
    public let text: String
    public let segments: [TranscriptionSegment]

    public init(task: String, language: String, duration: Double, text: String, segments: [TranscriptionSegment]) {
        self.task = task
        self.language = language
        self.duration = duration
        self.text = text
        self.segments = segments
    }
}

// MARK: - Transcription Segment

/// A segment of transcribed audio with timing information.
public struct TranscriptionSegment: Encodable, Sendable {
    public let id: Int
    public let start: Double
    public let end: Double
    public let text: String

    public init(id: Int, start: Double, end: Double, text: String) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }
}

// MARK: - OpenAI Error Response

/// Standard OpenAI error response format.
public struct OpenAIErrorResponse: Encodable, Sendable {
    public let error: ErrorDetail

    public init(error: ErrorDetail) {
        self.error = error
    }

    public struct ErrorDetail: Encodable, Sendable {
        public let message: String
        public let type: String
        public let param: String?
        public let code: String?

        public init(message: String, type: String, param: String?, code: String?) {
            self.message = message
            self.type = type
            self.param = param
            self.code = code
        }
    }
}
