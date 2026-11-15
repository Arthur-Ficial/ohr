// ============================================================================
// OhrError.swift - Speech-to-text error classification
// Part of ohr - On-device speech-to-text from the command line
// ============================================================================

import Foundation

public enum OhrError: Error, Equatable, Sendable {
    case unsupportedFormat(String)
    case fileNotFound(String)
    case transcriptionFailed(String)
    case noSpeechDetected
    case microphoneUnavailable
    case rateLimited
    case unsupportedLanguage(String)
    case unknown(String)

    /// Classify any thrown error into a typed OhrError.
    /// Matches on SpeechAnalyzer errors first, falls back to string matching.
    public static func classify(_ error: Error) -> OhrError {
        if let already = error as? OhrError { return already }

        // Try typed match first (Speech framework errors)
        let typeName = String(describing: type(of: error))
        let mirror = String(reflecting: error)
        if typeName.contains("SpeechAnalyzer") || typeName.contains("SpeechTranscriber") || mirror.contains("SpeechAnalyzer") {
            if mirror.contains("unsupportedFormat") || mirror.contains("unsupported format") {
                return .unsupportedFormat(error.localizedDescription)
            }
            if mirror.contains("noSpeechDetected") || mirror.contains("no speech") {
                return .noSpeechDetected
            }
            if mirror.contains("unsupportedLanguage") || mirror.contains("unsupported language") {
                return .unsupportedLanguage(error.localizedDescription)
            }
            if mirror.contains("rateLimited") {
                return .rateLimited
            }
        }

        // Fallback: string matching for unknown error types
        let desc = error.localizedDescription.lowercased()
        if desc.contains("unsupported") && desc.contains("format") {
            return .unsupportedFormat(error.localizedDescription)
        }
        if desc.contains("file not found") || desc.contains("no such file") {
            return .fileNotFound(error.localizedDescription)
        }
        if desc.contains("no speech") {
            return .noSpeechDetected
        }
        if desc.contains("rate limit") || desc.contains("ratelimited") || desc.contains("rate_limit") {
            return .rateLimited
        }
        if desc.contains("microphone") || (desc.contains("audio") && desc.contains("permission")) {
            return .microphoneUnavailable
        }
        if desc.contains("unsupported language") {
            return .unsupportedLanguage(error.localizedDescription)
        }
        return .unknown(error.localizedDescription)
    }

    public var cliLabel: String {
        switch self {
        case .unsupportedFormat:    return "[unsupported format]"
        case .fileNotFound:         return "[file not found]"
        case .transcriptionFailed:  return "[transcription failed]"
        case .noSpeechDetected:     return "[no speech]"
        case .microphoneUnavailable: return "[microphone unavailable]"
        case .rateLimited:          return "[rate limited]"
        case .unsupportedLanguage:  return "[unsupported language]"
        case .unknown:              return "[error]"
        }
    }

    public var openAIType: String {
        switch self {
        case .unsupportedFormat:    return "invalid_request_error"
        case .fileNotFound:         return "invalid_request_error"
        case .transcriptionFailed:  return "server_error"
        case .noSpeechDetected:     return "invalid_request_error"
        case .microphoneUnavailable: return "server_error"
        case .rateLimited:          return "rate_limit_error"
        case .unsupportedLanguage:  return "invalid_request_error"
        case .unknown:              return "server_error"
        }
    }

    public var httpStatusCode: Int {
        switch self {
        case .unsupportedFormat:    return 400
        case .fileNotFound:         return 400
        case .transcriptionFailed:  return 500
        case .noSpeechDetected:     return 400
        case .microphoneUnavailable: return 503
        case .rateLimited:          return 429
        case .unsupportedLanguage:  return 400
        case .unknown:              return 500
        }
    }

    public var openAIMessage: String {
        switch self {
        case .unsupportedFormat(let fmt):
            return "Unsupported audio format: \(fmt). Supported: m4a, wav, mp3, caf, aiff, flac."
        case .fileNotFound(let path):
            return "Audio file not found: \(path)"
        case .transcriptionFailed(let msg):
            return "Transcription failed: \(msg)"
        case .noSpeechDetected:
            return "No speech detected in the provided audio."
        case .microphoneUnavailable:
            return "Microphone is not available or permission was denied."
        case .rateLimited:
            return "Speech recognition is rate limited. Retry after a few seconds."
        case .unsupportedLanguage(let lang):
            return "Unsupported language: \(lang)"
        case .unknown(let msg):
            return msg
        }
    }
}
