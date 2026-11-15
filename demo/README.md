# ohr demos

Real-world shell scripts powered by ohr (and some by ohr + apfel).

## Scripts

### ohr only (no dependencies beyond ohr)

| Script | What it does |
|--------|-------------|
| **[subtitle](./subtitle)** | Generate SRT/VTT subtitles for any audio file |
| **[batch-transcribe](./batch-transcribe)** | Transcribe all audio files in a directory at once |
| **[voice-search](./voice-search)** | Search inside audio files by spoken content |
| **[audio-grep](./audio-grep)** | grep-like interface for audio - pattern matching with timestamps |
| **[dictate](./dictate)** | Speak into a text file using live microphone |
| **[live-caption](./live-caption)** | Real-time captions displayed in the terminal |
| **[whisper-compat](./whisper-compat)** | Drop-in replacement for OpenAI Whisper CLI |

### ohr + apfel (requires both)

| Script | What it does |
|--------|-------------|
| **[minutes](./minutes)** | Meeting recording to structured meeting minutes |
| **[action-items](./action-items)** | Extract to-dos and commitments from meetings |
| **[translate-audio](./translate-audio)** | Transcribe audio then translate to any language |
| **[podcast-chapters](./podcast-chapters)** | Generate timestamped chapter markers |
| **[voice-note](./voice-note)** | Record, transcribe, and optionally summarize |

## Quick examples

```bash
# Generate subtitles
demo/subtitle lecture.m4a --save

# Batch transcribe a folder
demo/batch-transcribe ~/recordings/ -o srt

# Search meetings for a topic
demo/audio-grep "deadline" ~/meetings/*.m4a

# Meeting minutes
demo/minutes standup.m4a -o markdown > standup.md

# Live captions
demo/live-caption

# Translate a recording
demo/translate-audio interview.m4a --from de-DE --to English

# Whisper drop-in replacement
demo/whisper-compat audio.m4a --output_format srt --language en
```

## Install

All scripts require [ohr](https://github.com/Arthur-Ficial/ohr). Some additionally require [apfel](https://github.com/Arthur-Ficial/apfel).

```bash
brew tap Arthur-Ficial/tap
brew install Arthur-Ficial/tap/ohr
brew install Arthur-Ficial/tap/apfel    # for ohr+apfel scripts
```

## Limits

- **apfel context window**: 4096 tokens (~3000 words). Long transcripts may be truncated when piped to apfel. For long recordings, the scripts work best with meetings under ~15 minutes.
- **ohr accuracy**: On-device model. Quality varies by language, accent, and audio quality. Works best with clear speech and low background noise.
- **Audio formats**: m4a, wav, mp3, mp4, caf, aiff, flac. No OGG or OPUS.
