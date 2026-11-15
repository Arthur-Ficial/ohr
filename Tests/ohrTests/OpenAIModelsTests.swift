// OpenAIModelsTests - TDD tests for transcription API types
// Tests response encoding and format type parsing

import Foundation
import OhrCore

func runOpenAIModelsTests() {
    // MARK: - ResponseFormatType

    test("ResponseFormatType json raw value") {
        try assertEqual(ResponseFormatType.json.rawValue, "json")
    }
    test("ResponseFormatType text raw value") {
        try assertEqual(ResponseFormatType.text.rawValue, "text")
    }
    test("ResponseFormatType srt raw value") {
        try assertEqual(ResponseFormatType.srt.rawValue, "srt")
    }
    test("ResponseFormatType verboseJSON raw value") {
        try assertEqual(ResponseFormatType.verboseJSON.rawValue, "verbose_json")
    }
    test("ResponseFormatType vtt raw value") {
        try assertEqual(ResponseFormatType.vtt.rawValue, "vtt")
    }
    test("ResponseFormatType init from string") {
        try assertEqual(ResponseFormatType(rawValue: "json"), .json)
        try assertEqual(ResponseFormatType(rawValue: "verbose_json"), .verboseJSON)
        try assertNil(ResponseFormatType(rawValue: "xml"))
    }

    // MARK: - TranscriptionResponse encoding

    test("TranscriptionResponse encodes to JSON with text field") {
        let resp = TranscriptionResponse(text: "Hello world")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try! encoder.encode(resp)
        let json = String(data: data, encoding: .utf8)!
        try assertTrue(json.contains("\"text\":\"Hello world\""))
    }

    // MARK: - VerboseTranscriptionResponse encoding

    test("VerboseTranscriptionResponse encodes with all fields") {
        let segment = TranscriptionSegment(id: 0, start: 0.0, end: 2.5, text: "Hello")
        let resp = VerboseTranscriptionResponse(
            task: "transcribe",
            language: "english",
            duration: 2.5,
            text: "Hello",
            segments: [segment]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try! encoder.encode(resp)
        let json = String(data: data, encoding: .utf8)!
        try assertTrue(json.contains("\"task\":\"transcribe\""))
        try assertTrue(json.contains("\"language\":\"english\""))
        try assertTrue(json.contains("\"duration\":2.5"))
        try assertTrue(json.contains("\"segments\""))
    }

    // MARK: - TranscriptionSegment encoding

    test("TranscriptionSegment encodes start and end as doubles") {
        let segment = TranscriptionSegment(id: 0, start: 1.5, end: 3.75, text: "Test")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try! encoder.encode(segment)
        let json = String(data: data, encoding: .utf8)!
        try assertTrue(json.contains("\"start\":1.5"))
        try assertTrue(json.contains("\"end\":3.75"))
        try assertTrue(json.contains("\"text\":\"Test\""))
    }

    // MARK: - OpenAIErrorResponse encoding

    test("OpenAIErrorResponse encodes with error object") {
        let resp = OpenAIErrorResponse(error: .init(
            message: "Bad request", type: "invalid_request_error", param: nil, code: nil
        ))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try! encoder.encode(resp)
        let json = String(data: data, encoding: .utf8)!
        try assertTrue(json.contains("\"message\":\"Bad request\""))
        try assertTrue(json.contains("\"type\":\"invalid_request_error\""))
    }
}
