// ============================================================================
// AudioFormat.swift - Audio format detection and validation
// Part of ohr - On-device speech-to-text from the command line
// ============================================================================

/// Supported audio formats for transcription.
public enum AudioFormat: String, CaseIterable, Sendable, Equatable {
    case m4a
    case wav
    case mp3
    case mp4
    case caf
    case aiff
    case flac

    /// Detect format from a filename's extension.
    public static func detect(filename: String) -> AudioFormat? {
        guard let dot = filename.lastIndex(of: ".") else { return nil }
        let ext = String(filename[filename.index(after: dot)...]).lowercased()
        return extensionMap[ext]
    }

    /// Detect format from a MIME type string.
    public static func detect(mimeType: String) -> AudioFormat? {
        let lower = mimeType.lowercased()
        return mimeTypeMap[lower]
    }

    /// Check if a filename has a supported audio extension.
    public static func isSupported(filename: String) -> Bool {
        detect(filename: filename) != nil
    }

    /// All supported file extensions.
    public static var allSupported: [String] {
        Array(extensionMap.keys).sorted()
    }

    /// The primary MIME type for this format.
    public var mimeType: String {
        switch self {
        case .m4a:  return "audio/x-m4a"
        case .wav:  return "audio/wav"
        case .mp3:  return "audio/mpeg"
        case .mp4:  return "audio/mp4"
        case .caf:  return "audio/x-caf"
        case .aiff: return "audio/aiff"
        case .flac: return "audio/flac"
        }
    }

    // MARK: - Private

    private static let extensionMap: [String: AudioFormat] = [
        "m4a": .m4a,
        "wav": .wav,
        "wave": .wav,
        "mp3": .mp3,
        "mp4": .mp4,
        "caf": .caf,
        "aiff": .aiff,
        "aif": .aiff,
        "flac": .flac,
    ]

    private static let mimeTypeMap: [String: AudioFormat] = [
        "audio/x-m4a": .m4a,
        "audio/mp4": .m4a,
        "audio/m4a": .m4a,
        "audio/wav": .wav,
        "audio/wave": .wav,
        "audio/x-wav": .wav,
        "audio/mpeg": .mp3,
        "audio/mp3": .mp3,
        "video/mp4": .mp4,
        "audio/x-caf": .caf,
        "audio/aiff": .aiff,
        "audio/x-aiff": .aiff,
        "audio/flac": .flac,
        "audio/x-flac": .flac,
    ]
}
