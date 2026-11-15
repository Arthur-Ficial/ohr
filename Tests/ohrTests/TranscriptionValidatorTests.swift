// TranscriptionValidatorTests - TDD tests for transcription request validation
// Tests format, temperature, language, and field validation

import OhrCore

func runTranscriptionValidatorTests() {
    // MARK: - Missing file

    test("missing filename fails") {
        let result = TranscriptionValidator.validate(filename: nil, responseFormat: nil, temperature: nil)
        try assertNotNil(result)
        if case .missingFile = result! { } else {
            throw TestFailure("expected .missingFile, got \(result!)")
        }
    }

    // MARK: - Unsupported format

    test("unsupported format .xyz fails") {
        let result = TranscriptionValidator.validate(filename: "audio.xyz", responseFormat: nil, temperature: nil)
        try assertNotNil(result)
        if case .unsupportedFormat = result! { } else {
            throw TestFailure("expected .unsupportedFormat, got \(result!)")
        }
    }
    test("supported format .m4a passes format check") {
        let result = TranscriptionValidator.validate(filename: "audio.m4a", responseFormat: nil, temperature: nil)
        try assertNil(result)
    }

    // MARK: - Invalid response format

    test("invalid response_format xml fails") {
        let result = TranscriptionValidator.validate(filename: "audio.m4a", responseFormat: "xml", temperature: nil)
        try assertNotNil(result)
        if case .invalidResponseFormat = result! { } else {
            throw TestFailure("expected .invalidResponseFormat, got \(result!)")
        }
    }
    test("valid response_format json passes") {
        let result = TranscriptionValidator.validate(filename: "audio.m4a", responseFormat: "json", temperature: nil)
        try assertNil(result)
    }
    test("valid response_format srt passes") {
        let result = TranscriptionValidator.validate(filename: "audio.m4a", responseFormat: "srt", temperature: nil)
        try assertNil(result)
    }
    test("valid response_format verbose_json passes") {
        let result = TranscriptionValidator.validate(filename: "audio.m4a", responseFormat: "verbose_json", temperature: nil)
        try assertNil(result)
    }
    test("valid response_format vtt passes") {
        let result = TranscriptionValidator.validate(filename: "audio.m4a", responseFormat: "vtt", temperature: nil)
        try assertNil(result)
    }

    // MARK: - Invalid temperature

    test("negative temperature fails") {
        let result = TranscriptionValidator.validate(filename: "audio.m4a", responseFormat: nil, temperature: -0.1)
        try assertNotNil(result)
        if case .invalidTemperature = result! { } else {
            throw TestFailure("expected .invalidTemperature, got \(result!)")
        }
    }
    test("temperature above 1.0 fails") {
        let result = TranscriptionValidator.validate(filename: "audio.m4a", responseFormat: nil, temperature: 1.5)
        try assertNotNil(result)
        if case .invalidTemperature = result! { } else {
            throw TestFailure("expected .invalidTemperature, got \(result!)")
        }
    }
    test("temperature 0.0 passes") {
        let result = TranscriptionValidator.validate(filename: "audio.m4a", responseFormat: nil, temperature: 0.0)
        try assertNil(result)
    }
    test("temperature 1.0 passes") {
        let result = TranscriptionValidator.validate(filename: "audio.m4a", responseFormat: nil, temperature: 1.0)
        try assertNil(result)
    }

    // MARK: - Valid requests

    test("minimal valid request passes") {
        let result = TranscriptionValidator.validate(filename: "audio.wav", responseFormat: nil, temperature: nil)
        try assertNil(result)
    }
    test("full valid request passes") {
        let result = TranscriptionValidator.validate(filename: "meeting.m4a", responseFormat: "verbose_json", temperature: 0.5)
        try assertNil(result)
    }
}
