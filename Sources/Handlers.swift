// ============================================================================
// Handlers.swift - Request handler for transcription endpoint
// Part of ohr - On-device speech-to-text from the command line
// ============================================================================

import Foundation
import Hummingbird
import OhrCore

/// Trace information for logging a transcription request.
struct TranscriptionTrace: Sendable {
    var events: [String] = []
    var error: String? = nil
}

/// Handle POST /v1/audio/transcriptions
/// Parses multipart/form-data, validates, transcribes, and returns the result.
func handleTranscription(
    _ request: Request,
    context: some RequestContext
) async throws -> (response: Response, trace: TranscriptionTrace) {
    var trace = TranscriptionTrace()

    // Get content type and boundary
    guard let contentType = request.headers[.contentType],
          contentType.contains("multipart/form-data"),
          let boundary = MultipartParser.extractBoundary(from: contentType) else {
        trace.error = "Invalid content type"
        trace.events.append("rejected: not multipart/form-data")
        let resp = openAIError(
            status: .badRequest,
            message: "Content-Type must be multipart/form-data.",
            type: "invalid_request_error"
        )
        return (resp, trace)
    }

    // Read body (limit: 100MB)
    let body = try await request.body.collect(upTo: 100 * 1024 * 1024)
    let bodyData = Data(buffer: body)
    trace.events.append("request bytes=\(bodyData.count)")

    // Parse multipart
    let parts = MultipartParser.parse(data: bodyData, boundary: boundary)
    trace.events.append("parsed \(parts.count) parts")

    // Extract fields
    var fileData: Data? = nil
    var filename: String? = nil
    var responseFormatStr: String? = nil
    var language: String? = nil
    var temperature: Double? = nil

    for part in parts {
        switch part.name {
        case "file":
            fileData = part.data
            filename = part.filename
        case "response_format":
            responseFormatStr = String(data: part.data, encoding: .utf8)
        case "language":
            language = String(data: part.data, encoding: .utf8)
        case "temperature":
            if let str = String(data: part.data, encoding: .utf8) {
                temperature = Double(str)
            }
        case "model":
            // Accept but don't use - we only have one model
            break
        case "prompt":
            // Accept but don't use - SpeechAnalyzer doesn't support prompting
            break
        default:
            break
        }
    }

    // Validate
    if let failure = TranscriptionValidator.validate(
        filename: filename,
        responseFormat: responseFormatStr,
        temperature: temperature
    ) {
        trace.error = failure.message
        trace.events.append("validation failed: \(failure.message)")
        let resp = openAIError(
            status: .badRequest,
            message: failure.message,
            type: "invalid_request_error"
        )
        return (resp, trace)
    }

    guard let fileData, !fileData.isEmpty else {
        trace.error = "Empty file"
        let resp = openAIError(
            status: .badRequest,
            message: "Audio file is empty.",
            type: "invalid_request_error"
        )
        return (resp, trace)
    }

    // Write to temp file
    let ext = filename.flatMap { URL(fileURLWithPath: $0).pathExtension } ?? "m4a"
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ohr-\(UUID().uuidString).\(ext)")
    defer { try? FileManager.default.removeItem(at: tempURL) }
    try fileData.write(to: tempURL)
    trace.events.append("wrote temp file \(tempURL.lastPathComponent) (\(fileData.count) bytes)")

    // Transcribe
    let result: TranscriptionResult
    do {
        result = try await transcribeFile(url: tempURL, language: language)
        trace.events.append("transcribed: \(result.segments.count) segments, \(String(format: "%.1f", result.duration))s")
    } catch {
        let classified = OhrError.classify(error)
        trace.error = classified.openAIMessage
        trace.events.append("transcription failed: \(classified.cliLabel)")
        let resp = openAIError(
            status: .init(code: classified.httpStatusCode),
            message: classified.openAIMessage,
            type: classified.openAIType
        )
        return (resp, trace)
    }

    // Format response
    let responseFormat = responseFormatStr.flatMap { ResponseFormatType(rawValue: $0) } ?? .json

    switch responseFormat {
    case .json:
        let resp = TranscriptionResponse(text: result.text)
        return (jsonResponse(jsonString(resp)), trace)

    case .verboseJSON:
        let segments = result.segments.map {
            TranscriptionSegment(id: $0.id, start: $0.start, end: $0.end, text: $0.text)
        }
        let resp = VerboseTranscriptionResponse(
            task: "transcribe",
            language: result.language,
            duration: result.duration,
            text: result.text,
            segments: segments
        )
        return (jsonResponse(jsonString(resp)), trace)

    case .text:
        var headers = HTTPFields()
        headers[.contentType] = "text/plain"
        let resp = Response(status: .ok, headers: headers, body: .init(byteBuffer: .init(string: result.text)))
        return (resp, trace)

    case .srt:
        var headers = HTTPFields()
        headers[.contentType] = "text/plain"
        let srt = SubtitleFormatter.formatSRT(segments: result.segments)
        let resp = Response(status: .ok, headers: headers, body: .init(byteBuffer: .init(string: srt)))
        return (resp, trace)

    case .vtt:
        var headers = HTTPFields()
        headers[.contentType] = "text/vtt"
        let vtt = SubtitleFormatter.formatVTT(segments: result.segments)
        let resp = Response(status: .ok, headers: headers, body: .init(byteBuffer: .init(string: vtt)))
        return (resp, trace)
    }
}
