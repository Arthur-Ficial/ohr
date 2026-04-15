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

    // Ask Speech what audio format the transcriber actually wants. Without
    // this, feeding the raw mic format (typically 48 kHz Float32) traps
    // deep inside Speech.framework with SIGTRAP on the cooperative queue.
    guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
        throw OhrError.transcriptionFailed("no compatible audio format for SpeechTranscriber")
    }

    let engine = AVAudioEngine()
    let inputNode = engine.inputNode
    let micFormat = inputNode.outputFormat(forBus: 0)

    // Converter from microphone format to the format Speech expects.
    guard let converter = AVAudioConverter(from: micFormat, to: analyzerFormat) else {
        throw OhrError.transcriptionFailed("cannot convert mic format \(micFormat) to analyzer format \(analyzerFormat)")
    }

    let (bufferStream, bufferContinuation) = AsyncStream<AnalyzerInput>.makeStream()

    inputNode.installTap(onBus: 0, bufferSize: 4096, format: micFormat) { buffer, _ in
        guard let converted = convertBuffer(buffer, with: converter, to: analyzerFormat) else { return }
        bufferContinuation.yield(AnalyzerInput(buffer: converted))
    }

    engine.prepare()
    try engine.start()

    let analyzer = SpeechAnalyzer(modules: [transcriber])
    try await analyzer.prepareToAnalyze(in: analyzerFormat)
    try await analyzer.start(inputSequence: bufferStream)

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

// MARK: - Audio Format Conversion

/// Convert a PCM buffer to the target format using the given converter.
/// Returns nil when the conversion fails or produces no frames.
func convertBuffer(
    _ source: AVAudioPCMBuffer,
    with converter: AVAudioConverter,
    to targetFormat: AVAudioFormat
) -> AVAudioPCMBuffer? {
    let ratio = targetFormat.sampleRate / source.format.sampleRate
    let capacity = AVAudioFrameCount(Double(source.frameLength) * ratio + 0.5)
    guard capacity > 0,
          let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
        return nil
    }

    let consumed = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
    consumed.initialize(to: false)
    defer { consumed.deallocate() }

    var error: NSError?
    let status = converter.convert(to: output, error: &error) { _, inputStatus in
        if consumed.pointee {
            inputStatus.pointee = .noDataNow
            return nil
        }
        consumed.pointee = true
        inputStatus.pointee = .haveData
        return source
    }

    guard status != .error, output.frameLength > 0 else { return nil }
    return output
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
