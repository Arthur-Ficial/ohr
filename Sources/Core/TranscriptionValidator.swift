// ============================================================================
// TranscriptionValidator.swift - Validate transcription request parameters
// Part of ohr - On-device speech-to-text from the command line
// ============================================================================

/// Validation failure types for transcription requests.
public enum TranscriptionValidationFailure: Sendable, Equatable {
    case missingFile
    case unsupportedFormat(String)
    case invalidResponseFormat(String)
    case invalidTemperature

    public var message: String {
        switch self {
        case .missingFile:
            return "No audio file provided."
        case .unsupportedFormat(let ext):
            return "Unsupported audio format: \(ext). Supported: \(AudioFormat.allSupported.joined(separator: ", "))."
        case .invalidResponseFormat(let fmt):
            return "Invalid response_format: \(fmt). Supported: json, text, srt, verbose_json, vtt."
        case .invalidTemperature:
            return "Temperature must be between 0.0 and 1.0."
        }
    }
}

/// Validates transcription request parameters.
public enum TranscriptionValidator {

    /// Validate a transcription request. Returns nil if valid, or a failure describing the problem.
    public static func validate(
        filename: String?,
        responseFormat: String?,
        temperature: Double?
    ) -> TranscriptionValidationFailure? {
        // File is required
        guard let filename else { return .missingFile }

        // Check audio format
        if !AudioFormat.isSupported(filename: filename) {
            let ext = filename.split(separator: ".").last.map(String.init) ?? filename
            return .unsupportedFormat(ext)
        }

        // Check response format if provided
        if let fmt = responseFormat {
            guard ResponseFormatType(rawValue: fmt) != nil else {
                return .invalidResponseFormat(fmt)
            }
        }

        // Check temperature if provided
        if let temp = temperature {
            guard temp >= 0.0 && temp <= 1.0 else {
                return .invalidTemperature
            }
        }

        return nil
    }
}
