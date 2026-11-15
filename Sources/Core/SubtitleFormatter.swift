// ============================================================================
// SubtitleFormatter.swift - SRT and VTT subtitle generation
// Part of ohr - On-device speech-to-text from the command line
// ============================================================================

import Foundation

/// A transcription segment with timing information.
/// Core-side type with no Speech framework dependency.
public struct SubtitleSegment: Sendable, Equatable {
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

/// Subtitle timestamp format.
public enum SubtitleFormat: Sendable {
    /// SRT uses comma as decimal separator: HH:MM:SS,mmm
    case srt
    /// VTT uses period as decimal separator: HH:MM:SS.mmm
    case vtt
}

/// Formats transcription segments as SRT or VTT subtitles.
public enum SubtitleFormatter {

    /// Format segments as SRT (SubRip Text).
    /// Numbers start at 1. Segments separated by blank lines.
    public static func formatSRT(segments: [SubtitleSegment]) -> String {
        guard !segments.isEmpty else { return "" }
        var lines: [String] = []
        for (index, segment) in segments.enumerated() {
            if index > 0 { lines.append("") }
            lines.append("\(index + 1)")
            lines.append("\(formatTimestamp(segment.start, format: .srt)) --> \(formatTimestamp(segment.end, format: .srt))")
            lines.append(segment.text)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Format segments as WebVTT.
    /// Includes WEBVTT header. No sequence numbers.
    public static func formatVTT(segments: [SubtitleSegment]) -> String {
        guard !segments.isEmpty else { return "WEBVTT\n" }
        var lines: [String] = ["WEBVTT"]
        for segment in segments {
            lines.append("")
            lines.append("\(formatTimestamp(segment.start, format: .vtt)) --> \(formatTimestamp(segment.end, format: .vtt))")
            lines.append(segment.text)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Format seconds as a subtitle timestamp.
    /// SRT: HH:MM:SS,mmm  VTT: HH:MM:SS.mmm
    public static func formatTimestamp(_ seconds: Double, format: SubtitleFormat) -> String {
        let totalMs = Int(round(seconds * 1000))
        let ms = totalMs % 1000
        let totalSeconds = totalMs / 1000
        let s = totalSeconds % 60
        let m = (totalSeconds / 60) % 60
        let h = totalSeconds / 3600
        let separator: Character = format == .srt ? "," : "."
        return String(format: "%02d:%02d:%02d\(separator)%03d", h, m, s, ms)
    }
}
