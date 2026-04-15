# ohr

[![Version 0.1.6](https://img.shields.io/badge/version-0.1.6-blue)](https://github.com/Arthur-Ficial/ohr)
[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/speech)

On-device speech-to-text on your Mac. Transcribe audio files, generate subtitles, stream from the microphone — all locally, no cloud.

No API keys. No network. No subscriptions. The speech recognition is already on your computer — ohr lets you use it.

## What is this

Every Mac with Apple Silicon has a **built-in speech recognizer** — Apple's on-device SpeechAnalyzer, shipped as part of the [Speech framework](https://developer.apple.com/documentation/speech) (macOS 26+). **ohr wraps it** in a CLI and an OpenAI-compatible HTTP server — so you can actually use it. All inference runs **on-device**, no network calls.

- **UNIX tool** — `ohr meeting.m4a` — file in, text out. Pipe-friendly, multiple output formats, proper exit codes
- **Subtitle generator** — `ohr -o srt lecture.wav > lecture.srt` — SRT and VTT with precise timestamps
- **Live transcription** — `ohr --listen` — real-time microphone input
- **OpenAI-compatible server** — `ohr --serve` — drop-in replacement for `POST /v1/audio/transcriptions`
- **Zero cost** — no API keys, no cloud, no subscriptions, 30 languages supported

## Requirements & Install

- Apple Silicon Mac, macOS 26 Tahoe or newer
- Building from source requires Command Line Tools with macOS 26 SDK (ships Swift 6.3). No Xcode required.

**Homebrew** (recommended):

```bash
brew tap Arthur-Ficial/tap
brew install Arthur-Ficial/tap/ohr
```

**Build from source:**

```bash
git clone https://github.com/Arthur-Ficial/ohr.git
cd ohr
make install
```

## Quick Start

### Transcribe a file

```bash
ohr meeting.m4a
```

### Generate subtitles

```bash
# SRT format
ohr -o srt lecture.wav > lecture.srt

# WebVTT format
ohr --vtt interview.m4a > interview.vtt
```

### JSON output with segments

```bash
ohr -o json recording.m4a | jq .
```

```json
{
  "model": "apple-speechanalyzer",
  "text": "Hello, this is a test of the speech to text system.",
  "segments": [
    { "id": 0, "start": 0.0, "end": 1.86, "text": "Hello, this is a test" },
    { "id": 1, "start": 1.86, "end": 4.44, "text": "of the speech to text system." }
  ],
  "duration": 4.44,
  "language": "en",
  "metadata": { "on_device": true, "version": "0.1.3" }
}
```

### Timestamps in plain text

```bash
ohr --timestamps meeting.m4a
```

```
[00:00:00,000] Hello, this is a test
[00:00:01,860] of the speech to text system.
```

### Pipe from stdin

```bash
cat recording.wav | ohr
```

### Pipe to apfel for summarization

```bash
ohr meeting.m4a | apfel "summarize this meeting"
```

### Live microphone transcription

```bash
ohr --listen                    # plain text with timestamps
ohr --listen --json             # JSONL stream
ohr --listen --srt              # SRT as you speak
```

### Select language

```bash
ohr -l de-DE meeting.m4a       # German
ohr -l fr-FR interview.m4a     # French
ohr -l ja-JP recording.m4a     # Japanese
```

### OpenAI-compatible server

```bash
# Start server
ohr --serve

# In another terminal:
curl -X POST http://localhost:11434/v1/audio/transcriptions \
  -F file=@meeting.m4a \
  -F model=apple-speechanalyzer
```

```json
{"text": "Hello, this is a test of the speech to text system."}
```

All five response formats:

```bash
# JSON (default)
curl -X POST http://localhost:11434/v1/audio/transcriptions \
  -F file=@audio.m4a -F response_format=json

# Verbose JSON (with segments, timestamps, duration)
curl -X POST http://localhost:11434/v1/audio/transcriptions \
  -F file=@audio.m4a -F response_format=verbose_json

# Plain text
curl -X POST http://localhost:11434/v1/audio/transcriptions \
  -F file=@audio.m4a -F response_format=text

# SRT subtitles
curl -X POST http://localhost:11434/v1/audio/transcriptions \
  -F file=@audio.m4a -F response_format=srt

# WebVTT subtitles
curl -X POST http://localhost:11434/v1/audio/transcriptions \
  -F file=@audio.m4a -F response_format=vtt
```

## Demos

See [`demo/`](./demo/) for real-world shell scripts powered by ohr.

**[subtitle](./demo/subtitle)** — generate subtitles:
```bash
demo/subtitle lecture.m4a --save           # saves lecture.srt next to file
```

**[audio-grep](./demo/audio-grep)** — search inside audio files:
```bash
demo/audio-grep "budget" meetings/*.m4a    # find mentions with timestamps
demo/audio-grep -c "deadline" *.m4a        # count matches per file
```

**[minutes](./demo/minutes)** — meeting to minutes (ohr + apfel):
```bash
demo/minutes standup.m4a -o markdown > standup.md
```

**[batch-transcribe](./demo/batch-transcribe)** — transcribe a whole folder:
```bash
demo/batch-transcribe ~/recordings/ -o srt
```

**[whisper-compat](./demo/whisper-compat)** — drop-in Whisper CLI replacement:
```bash
demo/whisper-compat audio.m4a --output_format srt --language en
```

Also in `demo/`:
- **[dictate](./demo/dictate)** — speak into a text file via microphone
- **[live-caption](./demo/live-caption)** — real-time captions in the terminal
- **[voice-search](./demo/voice-search)** — search spoken content across files
- **[translate-audio](./demo/translate-audio)** — transcribe then translate (ohr + apfel)
- **[action-items](./demo/action-items)** — extract to-dos from meetings (ohr + apfel)
- **[podcast-chapters](./demo/podcast-chapters)** — timestamped chapter markers (ohr + apfel)
- **[voice-note](./demo/voice-note)** — record, transcribe, and summarize (ohr + apfel)

## OpenAI API Compatibility

**Base URL:** `http://localhost:11434/v1`

| Feature | Status | Notes |
|---------|--------|-------|
| `POST /v1/audio/transcriptions` | Supported | All 5 response formats |
| `GET /v1/models` | Supported | Returns `apple-speechanalyzer` |
| `GET /health` | Supported | Model availability, formats, languages |
| `GET /v1/logs` | Debug only | Available with `--debug` |
| `GET /v1/logs/stats` | Debug only | Available with `--debug` |
| `response_format` | Supported | `json`, `verbose_json`, `text`, `srt`, `vtt` |
| `language` | Supported | BCP-47 language code |
| `model` | Accepted | Ignored (only one model) |
| `prompt` | Accepted | Ignored (SpeechAnalyzer doesn't support prompting) |
| `temperature` | Accepted | Validated (0.0–1.0) |
| CORS | Supported | Enable with `--cors` |
| Token auth | Supported | `--token <secret>` or `--token-auto` |
| `POST /v1/chat/completions` | 501 | Use [apfel](https://github.com/Arthur-Ficial/apfel) |
| `POST /v1/embeddings` | 501 | Use [kern](https://github.com/Arthur-Ficial/kern) |

## Supported Formats

| Format | Extensions |
|--------|-----------|
| Apple M4A | `.m4a` |
| WAV | `.wav`, `.wave` |
| MP3 | `.mp3` |
| MPEG-4 | `.mp4` |
| Core Audio | `.caf` |
| AIFF | `.aiff`, `.aif` |
| FLAC | `.flac` |

## Supported Languages

30 languages including English, German, Spanish, French, Italian, Japanese, Korean, Portuguese, Chinese (Simplified, Traditional, Cantonese).

```bash
ohr --model-info    # full list
```

## Performance

Tested on Apple M2 with synthetic speech. Real-world performance may vary.

| Audio Length | Transcribe Time | Speed |
|-------------|-----------------|-------|
| 5 seconds | 300ms | 8x real-time |
| 30 seconds | 600ms | 39x real-time |
| 1 minute | 1.5s | 46x real-time |
| 3 minutes | 2.5s | 58x real-time |
| 10 minutes | 4.7s | 57x real-time |

10 minutes of audio transcribes in under 5 seconds. No upper limit found.

## Limitations

| Constraint | Detail |
|------------|--------|
| Platform | macOS 26+, Apple Silicon only |
| Model | One model (`apple-speechanalyzer`), not configurable |
| Accuracy | ~90-95% on clear synthetic speech. Lower on real speech with noise, accents, or multiple speakers |
| Numbers | Spoken numbers sometimes confused with ordinals ("five second" → "52nd") |
| Languages | 30 languages supported, but accuracy tested only for English. Other languages need the `-l` flag |
| No diarization | Cannot distinguish between different speakers |
| Audio formats | m4a, wav, mp3, mp4, caf, aiff, flac. No OGG, OPUS, or WebM |
| apfel integration | When piping to apfel, transcripts longer than ~3000 words may exceed apfel's 4096-token context window |
| Testing gap | All testing used synthetic `say` command speech, not real human recordings |

See [docs/testing.md](docs/testing.md) for the full QA report with methodology and detailed results.

## CLI Reference

```
ohr <file>                     Transcribe audio file
ohr -o srt <file>              Generate SRT subtitles
ohr -o vtt <file>              Generate VTT subtitles
ohr -o json <file>             JSON output with segments
ohr --listen                   Live microphone transcription
ohr --serve                    Start OpenAI-compatible server
cat audio.wav | ohr            Transcribe from stdin
```

**Output options:**

| Flag | Description |
|------|-------------|
| `-o, --output <fmt>` | Output format: `plain` (default), `json`, `srt`, `vtt` |
| `--json` | Shorthand for `-o json` |
| `--srt` | Shorthand for `-o srt` |
| `--vtt` | Shorthand for `-o vtt` |
| `--timestamps` | Show timestamps in plain text output |
| `-l, --language <code>` | Language code (e.g. `en-US`, `de-DE`) |
| `-q, --quiet` | Suppress headers and chrome |
| `--no-color` | Disable ANSI colors |

**Server options** (`--serve`):

| Flag | Description |
|------|-------------|
| `--port <n>` | Server port (default: 11434) |
| `--host <addr>` | Bind address (default: 127.0.0.1) |
| `--cors` | Enable CORS headers for browser clients |
| `--allowed-origins <origins>` | Add comma-separated allowed origins |
| `--no-origin-check` | Disable origin checking |
| `--token <secret>` | Require Bearer token authentication |
| `--token-auto` | Generate and print a random Bearer token |
| `--public-health` | Keep `/health` unauthenticated on non-loopback |
| `--footgun` | Disable all protections |
| `--max-concurrent <n>` | Max concurrent requests (default: 5) |
| `--debug` | Verbose logging and enable `/v1/logs` endpoints |

**Info options:**

| Flag | Description |
|------|-------------|
| `-v, --version` | Print version |
| `-h, --help` | Show help |
| `--release` | Show detailed build info |
| `--model-info` | Show model capabilities and languages |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Runtime error |
| 2 | Usage error (bad flags) |
| 3 | Unsupported audio format |
| 4 | File not found |
| 5 | Transcription failed |
| 6 | Rate limited |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `OHR_PORT` | Server port (default: 11434) |
| `OHR_HOST` | Server bind address (default: 127.0.0.1) |
| `OHR_TOKEN` | Bearer token for server authentication |
| `OHR_LANGUAGE` | Default language code |
| `NO_COLOR` | Disable colors ([no-color.org](https://no-color.org)) |

## Architecture

```
CLI (file/stdin/mic) ──┐
                       ├──→ Speech.SpeechAnalyzer (file transcription)
                       ├──→ Speech.SpeechTranscriber (live microphone)
HTTP Server (/v1/*) ───┘    (100% on-device, zero network)
```

Built with Swift 6.3 strict concurrency. Single `Package.swift`, three targets:
- `OhrCore` — pure logic library (no Speech framework dependency, unit-testable)
- `ohr` — executable (CLI + server)
- `ohr-tests` — 109 unit tests

**No Xcode required.** Builds and tests with Command Line Tools only.

## Build & Test

```bash
# Build + install (auto-bumps patch version each time)
make install                             # build release + install to /usr/local/bin
make build                               # build release only (no install)

# Version management (zero manual editing)
make version                             # print current version
make release-minor                       # bump minor: 0.1.x -> 0.2.0
make release-major                       # bump major: 0.x.y -> 1.0.0

# Debug build (no version bump, uses swift directly)
swift build                              # quick debug build

# Unit tests
swift run ohr-tests                      # 109 pure Swift unit tests (no XCTest needed)

# Integration tests (requires server running)
ohr --serve --token test --debug &       # start server
OHR_TEST_TOKEN=test python3 -m pytest Tests/integration/ -v  # 42 integration tests
```

Every `make build`/`make install` automatically:
- Bumps the patch version (`.version` file is the single source of truth)
- Generates build metadata (commit, date, Swift version) viewable via `ohr --release`

## Part of the apfel ecosystem

| Tool | What | Apple Framework | Repo |
|------|------|-----------------|------|
| [apfel](https://github.com/Arthur-Ficial/apfel) | LLM (text generation) | FoundationModels | golden example |
| **ohr** | Speech-to-text | SpeechAnalyzer | you are here |
| [kern](https://github.com/Arthur-Ficial/kern) | Text embeddings | NLContextualEmbedding | sister project |
| [auge](https://github.com/Arthur-Ficial/auge) | Vision / OCR | Vision | sister project |

Meta-repo: [apfel-ecosystem](https://github.com/Arthur-Ficial/apfel-ecosystem)

## License

[MIT](LICENSE)
