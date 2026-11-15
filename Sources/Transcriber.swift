// ============================================================================
// Transcriber.swift - SpeechAnalyzer wrapper for file and mic transcription
// Part of ohr - On-device speech-to-text from the command line
// ============================================================================

import Foundation
import Speech
import AVFAudio
import CoreMedia
import OhrCore

// MARK: - Transcription Result

/// Result of a file transcription, containing text, segments, and metadata.
struct TranscriptionResult: Sendable {
    let text: String
    let segments: [SubtitleSegment]
    let language: String
    let duration: Double
}

// MARK: - File Transcription

/// Transcribe an audio file using SpeechAnalyzer + SpeechTranscriber module.
/// - Parameters:
///   - fileURL: Path to the audio file
///   - language: Optional BCP-47 language code (e.g. "en-US"). Nil = current locale.
/// - Returns: TranscriptionResult with text, segments, and metadata
func transcribeFile(url fileURL: URL, language: String? = nil) async throws -> TranscriptionResult {
    let locale = language.map { Locale(identifier: $0) } ?? .current
    let transcriber = SpeechTranscriber(locale: locale, preset: .timeIndexedTranscriptionWithAlternatives)

    let audioFile = try AVAudioFile(forReading: fileURL)
    let _ = try await SpeechAnalyzer(
        inputAudioFile: audioFile,
        modules: [transcriber],
        finishAfterFile: true
    )

    var allText = ""
    var segments: [SubtitleSegment] = []
    var segmentId = 0
    var maxEnd: Double = 0

    for try await result in transcriber.results {
        let text = String(result.text.characters)
        let start = CMTimeGetSeconds(result.range.start)
        let end = CMTimeGetSeconds(result.range.end)

        allText += (allText.isEmpty ? "" : " ") + text
        segments.append(SubtitleSegment(id: segmentId, start: start, end: end, text: text))
        segmentId += 1
        if end > maxEnd { maxEnd = end }
    }

    let detectedLanguage = language ?? locale.language.languageCode?.identifier ?? "en"

    return TranscriptionResult(
        text: allText,
        segments: segments,
        language: detectedLanguage,
        duration: maxEnd
    )
}

// MARK: - Microphone Transcription

/// Stream live transcription from the microphone using SpeechTranscriber.
/// Uses SpeechAnalyzer with a live audio input sequence.
/// - Parameters:
///   - language: Optional BCP-47 language code. Nil = current locale.
///   - onSegment: Callback for each transcribed segment.
func streamMicrophone(language: String? = nil, onSegment: @Sendable (SubtitleSegment) -> Void) async throws {
    let locale = language.map { Locale(identifier: $0) } ?? .current
    let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)

    let analyzer = SpeechAnalyzer(modules: [transcriber])

    // Set up audio engine for microphone capture
    let engine = AVAudioEngine()
    let inputNode = engine.inputNode
    let format = inputNode.outputFormat(forBus: 0)

    // Create an async stream of audio buffers
    let (bufferStream, bufferContinuation) = AsyncStream<AnalyzerInput>.makeStream()

    inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
        bufferContinuation.yield(AnalyzerInput(buffer: buffer))
    }

    engine.prepare()
    try engine.start()

    // Start the analyzer with the audio stream
    try await analyzer.start(inputSequence: bufferStream)

    var segmentId = 0
    for try await result in transcriber.results {
        let text = String(result.text.characters)
        let start = CMTimeGetSeconds(result.range.start)
        let end = CMTimeGetSeconds(result.range.end)
        let segment = SubtitleSegment(id: segmentId, start: start, end: end, text: text)
        onSegment(segment)
        segmentId += 1
    }

    engine.stop()
    inputNode.removeTap(onBus: 0)
}

// MARK: - Model Info

/// Check if SpeechTranscriber is available on this system.
func isSpeechAvailable() -> Bool {
    SpeechTranscriber.isAvailable
}

/// Get supported locales for speech recognition.
func speechSupportedLocales() async -> [String] {
    await SpeechTranscriber.supportedLocales.map { $0.identifier }.sorted()
}
