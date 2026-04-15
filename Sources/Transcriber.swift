// ============================================================================
// Transcriber.swift — SpeechAnalyzer wrapper for file and mic transcription
// Part of ohr — On-device speech-to-text from the command line
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

/// Resolve the requested locale to a supported one, then ensure its speech
/// asset is installed. Returns the resolved locale. Throws OhrError on
/// unsupported language or download failure.
func resolveAndInstallSpeechAsset(for requested: Locale) async throws -> Locale {
    let supported = await SpeechTranscriber.supportedLocales
    guard let resolved = resolveSupportedLocale(requested: requested, supported: supported) else {
        throw OhrError.unsupportedLanguage(canonicalLanguageRegion(requested))
    }

    let target = canonicalLanguageRegion(resolved)
    let installed = await Set(SpeechTranscriber.installedLocales.map { canonicalLanguageRegion($0) })
    if installed.contains(target) { return resolved }

    let installer = SpeechTranscriber(locale: resolved, preset: .progressiveTranscription)
    printStderr(styled("Downloading speech model for \(target) (first run only)...", .dim))
    guard let request = try await AssetInventory.assetInstallationRequest(supporting: [installer]) else {
        throw OhrError.transcriptionFailed("speech model for \(target) is not downloadable on this system")
    }
    try await request.downloadAndInstall()
    printStderr(styled("Speech model ready.", .dim))
    return resolved
}

// MARK: - Buffer copy

/// Deep-copy a PCM buffer so it outlives the audio tap callback.
/// Returns nil when the copy fails (different formats, zero-length, etc.).
func copyPCMBuffer(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    guard let copy = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameCapacity) else {
        return nil
    }
    copy.frameLength = source.frameLength
    let channelCount = Int(source.format.channelCount)
    let frames = Int(source.frameLength)

    if let src = source.floatChannelData, let dst = copy.floatChannelData {
        for c in 0..<channelCount {
            dst[c].update(from: src[c], count: frames)
        }
    } else if let src = source.int16ChannelData, let dst = copy.int16ChannelData {
        for c in 0..<channelCount {
            dst[c].update(from: src[c], count: frames)
        }
    } else if let src = source.int32ChannelData, let dst = copy.int32ChannelData {
        for c in 0..<channelCount {
            dst[c].update(from: src[c], count: frames)
        }
    } else {
        return nil
    }
    return copy
}

// MARK: - Microphone Transcription

/// Stream live transcription from the microphone using SpeechTranscriber.
/// Uses SpeechAnalyzer with a live audio input sequence.
/// - Parameters:
///   - language: Optional BCP-47 language code. Nil = current locale.
///   - onSegment: Callback for each transcribed segment.
func streamMicrophone(language: String? = nil, onSegment: @Sendable @escaping (SubtitleSegment) -> Void) async throws {
    let locale = language.map { Locale(identifier: $0) } ?? .current

    guard SpeechTranscriber.isAvailable else {
        throw OhrError.transcriptionFailed("SpeechTranscriber is not available on this system")
    }

    let resolved = try await resolveAndInstallSpeechAsset(for: locale)
    let transcriber = SpeechTranscriber(locale: resolved, preset: .progressiveTranscription)

    let engine = AVAudioEngine()
    let inputNode = engine.inputNode
    let format = inputNode.outputFormat(forBus: 0)

    let (bufferStream, bufferContinuation) = AsyncStream<AnalyzerInput>.makeStream()

    inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
        // Copy the buffer so it outlives the audio thread callback before
        // SpeechAnalyzer consumes it on its own queue.
        guard let copy = copyPCMBuffer(buffer) else { return }
        bufferContinuation.yield(AnalyzerInput(buffer: copy))
    }

    // Wiring: construct the analyzer *with* the input sequence and modules.
    // This is the supported pattern for live audio on macOS 26; the analyzer
    // reads from the sequence concurrently without a separate .start() call.
    let _ = SpeechAnalyzer(inputSequence: bufferStream, modules: [transcriber])

    engine.prepare()
    try engine.start()

    defer {
        bufferContinuation.finish()
        engine.stop()
        inputNode.removeTap(onBus: 0)
    }

    var segmentId = 0
    for try await result in transcriber.results {
        let text = String(result.text.characters)
        let start = CMTimeGetSeconds(result.range.start)
        let end = CMTimeGetSeconds(result.range.end)
        onSegment(SubtitleSegment(id: segmentId, start: start, end: end, text: text))
        segmentId += 1
    }
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
