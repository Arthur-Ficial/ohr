// OhrErrorTests - TDD tests for speech-to-text error classification
// Tests error classification, labels, HTTP codes, and OpenAI types

import Foundation
import OhrCore

func runOhrErrorTests() {
    test("unsupported format keyword → .unsupportedFormat") {
        let err = NSError(domain: "Speech", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "unsupported audio format: ogg"])
        if case .unsupportedFormat = OhrError.classify(err) { } else {
            throw TestFailure("expected .unsupportedFormat")
        }
    }
    test("file not found keyword → .fileNotFound") {
        let err = NSError(domain: "Speech", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "file not found at path /tmp/missing.m4a"])
        if case .fileNotFound = OhrError.classify(err) { } else {
            throw TestFailure("expected .fileNotFound")
        }
    }
    test("no speech detected keyword → .noSpeechDetected") {
        let err = NSError(domain: "Speech", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "no speech detected in audio"])
        try assertEqual(OhrError.classify(err), .noSpeechDetected)
    }
    test("rate limit keyword → .rateLimited") {
        let err = NSError(domain: "Speech", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "rate limited, try later"])
        try assertEqual(OhrError.classify(err), .rateLimited)
    }
    test("microphone keyword → .microphoneUnavailable") {
        let err = NSError(domain: "Speech", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "microphone not available or permission denied"])
        try assertEqual(OhrError.classify(err), .microphoneUnavailable)
    }
    test("unsupported language keyword → .unsupportedLanguage") {
        let err = NSError(domain: "Speech", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "unsupported language: klingon"])
        if case .unsupportedLanguage = OhrError.classify(err) { } else {
            throw TestFailure("expected .unsupportedLanguage")
        }
    }
    test("unknown error → .unknown") {
        let err = NSError(domain: "Speech", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "something went wrong"])
        if case .unknown = OhrError.classify(err) { } else {
            throw TestFailure("expected .unknown")
        }
    }
    test("classify passes through existing OhrError unchanged") {
        try assertEqual(OhrError.classify(OhrError.noSpeechDetected), .noSpeechDetected)
        try assertEqual(OhrError.classify(OhrError.rateLimited), .rateLimited)
        try assertEqual(OhrError.classify(OhrError.microphoneUnavailable), .microphoneUnavailable)
    }
    test("CLI labels") {
        try assertEqual(OhrError.unsupportedFormat("ogg").cliLabel, "[unsupported format]")
        try assertEqual(OhrError.fileNotFound("/tmp/x").cliLabel, "[file not found]")
        try assertEqual(OhrError.transcriptionFailed("x").cliLabel, "[transcription failed]")
        try assertEqual(OhrError.noSpeechDetected.cliLabel, "[no speech]")
        try assertEqual(OhrError.microphoneUnavailable.cliLabel, "[microphone unavailable]")
        try assertEqual(OhrError.rateLimited.cliLabel, "[rate limited]")
        try assertEqual(OhrError.unsupportedLanguage("x").cliLabel, "[unsupported language]")
        try assertEqual(OhrError.unknown("x").cliLabel, "[error]")
    }
    test("OpenAI error types") {
        try assertEqual(OhrError.unsupportedFormat("ogg").openAIType, "invalid_request_error")
        try assertEqual(OhrError.fileNotFound("/tmp/x").openAIType, "invalid_request_error")
        try assertEqual(OhrError.noSpeechDetected.openAIType, "invalid_request_error")
        try assertEqual(OhrError.rateLimited.openAIType, "rate_limit_error")
        try assertEqual(OhrError.unknown("x").openAIType, "server_error")
    }
    test("HTTP status codes") {
        try assertEqual(OhrError.unsupportedFormat("ogg").httpStatusCode, 400)
        try assertEqual(OhrError.fileNotFound("/tmp/x").httpStatusCode, 400)
        try assertEqual(OhrError.transcriptionFailed("x").httpStatusCode, 500)
        try assertEqual(OhrError.noSpeechDetected.httpStatusCode, 400)
        try assertEqual(OhrError.microphoneUnavailable.httpStatusCode, 503)
        try assertEqual(OhrError.rateLimited.httpStatusCode, 429)
        try assertEqual(OhrError.unsupportedLanguage("x").httpStatusCode, 400)
        try assertEqual(OhrError.unknown("x").httpStatusCode, 500)
    }
    test("openAIMessage is non-empty for all cases") {
        let cases: [OhrError] = [
            .unsupportedFormat("ogg"), .fileNotFound("/tmp/x"),
            .transcriptionFailed("fail"), .noSpeechDetected,
            .microphoneUnavailable, .rateLimited,
            .unsupportedLanguage("xx"), .unknown("oops")
        ]
        for c in cases {
            try assertTrue(!c.openAIMessage.isEmpty, "\(c)")
        }
    }
}
