// AudioFormatTests - TDD tests for audio format detection
// Tests extension-based and MIME-type-based format detection

import OhrCore

func runAudioFormatTests() {
    // MARK: - Detect from filename

    test("detect .m4a from filename") {
        try assertEqual(AudioFormat.detect(filename: "meeting.m4a"), .m4a)
    }
    test("detect .wav from filename") {
        try assertEqual(AudioFormat.detect(filename: "recording.wav"), .wav)
    }
    test("detect .mp3 from filename") {
        try assertEqual(AudioFormat.detect(filename: "song.mp3"), .mp3)
    }
    test("detect .caf from filename") {
        try assertEqual(AudioFormat.detect(filename: "system.caf"), .caf)
    }
    test("detect .aiff from filename") {
        try assertEqual(AudioFormat.detect(filename: "music.aiff"), .aiff)
    }
    test("detect .flac from filename") {
        try assertEqual(AudioFormat.detect(filename: "lossless.flac"), .flac)
    }
    test("detect .mp4 from filename") {
        try assertEqual(AudioFormat.detect(filename: "video.mp4"), .mp4)
    }
    test("detect case-insensitive .M4A") {
        try assertEqual(AudioFormat.detect(filename: "MEETING.M4A"), .m4a)
    }
    test("unknown extension returns nil") {
        try assertNil(AudioFormat.detect(filename: "file.xyz"))
    }
    test("no extension returns nil") {
        try assertNil(AudioFormat.detect(filename: "noextension"))
    }

    // MARK: - Detect from MIME type

    test("detect audio/x-m4a MIME") {
        try assertEqual(AudioFormat.detect(mimeType: "audio/x-m4a"), .m4a)
    }
    test("detect audio/mp4 MIME") {
        try assertEqual(AudioFormat.detect(mimeType: "audio/mp4"), .m4a)
    }
    test("detect audio/wav MIME") {
        try assertEqual(AudioFormat.detect(mimeType: "audio/wav"), .wav)
    }
    test("detect audio/mpeg MIME") {
        try assertEqual(AudioFormat.detect(mimeType: "audio/mpeg"), .mp3)
    }
    test("detect audio/x-caf MIME") {
        try assertEqual(AudioFormat.detect(mimeType: "audio/x-caf"), .caf)
    }
    test("detect audio/aiff MIME") {
        try assertEqual(AudioFormat.detect(mimeType: "audio/aiff"), .aiff)
    }
    test("detect audio/flac MIME") {
        try assertEqual(AudioFormat.detect(mimeType: "audio/flac"), .flac)
    }
    test("unknown MIME returns nil") {
        try assertNil(AudioFormat.detect(mimeType: "application/pdf"))
    }

    // MARK: - MIME type property

    test("m4a mimeType is audio/x-m4a") {
        try assertEqual(AudioFormat.m4a.mimeType, "audio/x-m4a")
    }
    test("wav mimeType is audio/wav") {
        try assertEqual(AudioFormat.wav.mimeType, "audio/wav")
    }
    test("mp3 mimeType is audio/mpeg") {
        try assertEqual(AudioFormat.mp3.mimeType, "audio/mpeg")
    }

    // MARK: - isSupported

    test("isSupported returns true for .m4a") {
        try assertTrue(AudioFormat.isSupported(filename: "test.m4a"))
    }
    test("isSupported returns false for .xyz") {
        try assertTrue(!AudioFormat.isSupported(filename: "test.xyz"))
    }

    // MARK: - allSupported

    test("allSupported contains at least 7 formats") {
        try assertTrue(AudioFormat.allSupported.count >= 7)
    }
}
