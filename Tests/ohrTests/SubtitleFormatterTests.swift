// SubtitleFormatterTests - TDD tests for SRT and VTT subtitle generation
// Tests timestamp formatting, segment numbering, and edge cases

import OhrCore

func runSubtitleFormatterTests() {
    // MARK: - Timestamp formatting

    test("SRT timestamp for 0.0 seconds") {
        try assertEqual(SubtitleFormatter.formatTimestamp(0.0, format: .srt), "00:00:00,000")
    }
    test("SRT timestamp for 1.5 seconds") {
        try assertEqual(SubtitleFormatter.formatTimestamp(1.5, format: .srt), "00:00:01,500")
    }
    test("SRT timestamp for 61.123 seconds") {
        try assertEqual(SubtitleFormatter.formatTimestamp(61.123, format: .srt), "00:01:01,123")
    }
    test("SRT timestamp for 3661.5 seconds (1h 1m 1.5s)") {
        try assertEqual(SubtitleFormatter.formatTimestamp(3661.5, format: .srt), "01:01:01,500")
    }
    test("VTT timestamp for 0.0 seconds") {
        try assertEqual(SubtitleFormatter.formatTimestamp(0.0, format: .vtt), "00:00:00.000")
    }
    test("VTT timestamp for 1.5 seconds") {
        try assertEqual(SubtitleFormatter.formatTimestamp(1.5, format: .vtt), "00:00:01.500")
    }
    test("VTT timestamp for 3661.5 seconds") {
        try assertEqual(SubtitleFormatter.formatTimestamp(3661.5, format: .vtt), "01:01:01.500")
    }
    test("timestamp for 59.999 seconds rounds correctly") {
        let result = SubtitleFormatter.formatTimestamp(59.999, format: .srt)
        try assertEqual(result, "00:00:59,999")
    }

    // MARK: - SRT formatting

    test("SRT single segment") {
        let segments = [SubtitleSegment(id: 0, start: 0.0, end: 2.5, text: "Hello world")]
        let result = SubtitleFormatter.formatSRT(segments: segments)
        let expected = "1\n00:00:00,000 --> 00:00:02,500\nHello world\n"
        try assertEqual(result, expected)
    }
    test("SRT multi-segment") {
        let segments = [
            SubtitleSegment(id: 0, start: 0.0, end: 2.0, text: "First line"),
            SubtitleSegment(id: 1, start: 2.5, end: 5.0, text: "Second line"),
        ]
        let result = SubtitleFormatter.formatSRT(segments: segments)
        let expected = "1\n00:00:00,000 --> 00:00:02,000\nFirst line\n\n2\n00:00:02,500 --> 00:00:05,000\nSecond line\n"
        try assertEqual(result, expected)
    }
    test("SRT numbering starts at 1") {
        let segments = [SubtitleSegment(id: 42, start: 0.0, end: 1.0, text: "Test")]
        let result = SubtitleFormatter.formatSRT(segments: segments)
        try assertTrue(result.hasPrefix("1\n"), "SRT should start with sequence number 1")
    }
    test("SRT empty segments") {
        let result = SubtitleFormatter.formatSRT(segments: [])
        try assertEqual(result, "")
    }

    // MARK: - VTT formatting

    test("VTT has WEBVTT header") {
        let segments = [SubtitleSegment(id: 0, start: 0.0, end: 1.0, text: "Hello")]
        let result = SubtitleFormatter.formatVTT(segments: segments)
        try assertTrue(result.hasPrefix("WEBVTT\n"), "VTT must start with WEBVTT header")
    }
    test("VTT single segment") {
        let segments = [SubtitleSegment(id: 0, start: 0.0, end: 2.5, text: "Hello world")]
        let result = SubtitleFormatter.formatVTT(segments: segments)
        let expected = "WEBVTT\n\n00:00:00.000 --> 00:00:02.500\nHello world\n"
        try assertEqual(result, expected)
    }
    test("VTT multi-segment") {
        let segments = [
            SubtitleSegment(id: 0, start: 0.0, end: 2.0, text: "First"),
            SubtitleSegment(id: 1, start: 2.5, end: 5.0, text: "Second"),
        ]
        let result = SubtitleFormatter.formatVTT(segments: segments)
        let expected = "WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nFirst\n\n00:00:02.500 --> 00:00:05.000\nSecond\n"
        try assertEqual(result, expected)
    }
    test("VTT empty segments") {
        let result = SubtitleFormatter.formatVTT(segments: [])
        try assertEqual(result, "WEBVTT\n")
    }
}
