"""CLI end-to-end tests for ohr."""

import json
import os
import subprocess
import tempfile

import pytest


@pytest.fixture
def ohr(ohr_binary):
    def run(*args, input=None, timeout=30):
        result = subprocess.run(
            [ohr_binary, *args],
            capture_output=True,
            text=True,
            input=input,
            timeout=timeout,
        )
        return result

    return run


# --- Help, version, release ---


class TestInfoCommands:
    def test_help_shows_usage(self, ohr):
        r = ohr("--help")
        assert r.returncode == 0
        assert "USAGE:" in r.stdout
        assert "ohr <file>" in r.stdout

    def test_version_format(self, ohr):
        r = ohr("--version")
        assert r.returncode == 0
        assert r.stdout.startswith("ohr ")

    def test_release_shows_build_info(self, ohr):
        r = ohr("--release")
        assert r.returncode == 0
        assert "commit:" in r.stdout
        assert "framework:" in r.stdout
        assert "SpeechAnalyzer" in r.stdout

    def test_model_info_shows_capabilities(self, ohr):
        r = ohr("--model-info")
        assert r.returncode == 0
        assert "apple-speechanalyzer" in r.stdout
        assert "languages:" in r.stdout


# --- Exit codes ---


class TestExitCodes:
    def test_no_args_exits_2(self, ohr):
        r = ohr()
        assert r.returncode == 2

    def test_unknown_flag_exits_2(self, ohr):
        r = ohr("--bogus-flag")
        assert r.returncode == 2

    def test_missing_file_exits_4(self, ohr):
        r = ohr("/tmp/nonexistent-audio-file.m4a")
        assert r.returncode == 4
        assert "file not found" in r.stderr.lower()

    def test_unsupported_format_exits_3(self, ohr):
        # Create a file with unsupported extension
        with tempfile.NamedTemporaryFile(suffix=".xyz", delete=False) as f:
            f.write(b"not audio")
            path = f.name
        try:
            r = ohr(path)
            assert r.returncode == 3
            assert "unsupported format" in r.stderr.lower()
        finally:
            os.unlink(path)


# --- File transcription ---


class TestFileTranscription:
    def test_plain_output(self, ohr, test_audio_m4a):
        r = ohr(test_audio_m4a)
        assert r.returncode == 0
        assert len(r.stdout.strip()) > 0

    def test_json_output(self, ohr, test_audio_m4a):
        r = ohr("-o", "json", test_audio_m4a)
        assert r.returncode == 0
        data = json.loads(r.stdout)
        assert "text" in data
        assert "model" in data
        assert data["model"] == "apple-speechanalyzer"
        assert "segments" in data
        assert "duration" in data
        assert "metadata" in data
        assert data["metadata"]["on_device"] is True

    def test_srt_output(self, ohr, test_audio_m4a):
        r = ohr("--srt", test_audio_m4a)
        assert r.returncode == 0
        assert "-->" in r.stdout
        assert r.stdout.startswith("1\n")

    def test_vtt_output(self, ohr, test_audio_m4a):
        r = ohr("--vtt", test_audio_m4a)
        assert r.returncode == 0
        assert r.stdout.startswith("WEBVTT\n")
        assert "-->" in r.stdout

    def test_timestamps_output(self, ohr, test_audio_m4a):
        r = ohr("--timestamps", test_audio_m4a)
        assert r.returncode == 0
        assert "[00:00:" in r.stdout

    def test_wav_file(self, ohr, test_audio_wav):
        r = ohr(test_audio_wav)
        assert r.returncode == 0
        assert len(r.stdout.strip()) > 0

    def test_language_flag(self, ohr, test_audio_m4a):
        r = ohr("-l", "en-US", test_audio_m4a)
        assert r.returncode == 0
        assert len(r.stdout.strip()) > 0

    def test_quiet_suppresses_chrome(self, ohr, test_audio_m4a):
        r = ohr("-q", test_audio_m4a)
        assert r.returncode == 0
        # No stderr chrome in quiet mode for file transcription
        # (only relevant for --listen mode)


# --- Stdin piping ---


class TestStdinPiping:
    def test_stdin_wav(self, ohr, test_audio_wav):
        with open(test_audio_wav, "rb") as f:
            audio_data = f.read()
        r = subprocess.run(
            [ohr.__self__ if hasattr(ohr, "__self__") else os.environ.get("OHR_TEST_BINARY", "ohr")],
            input=audio_data,
            capture_output=True,
            timeout=30,
        )
        assert r.returncode == 0
        assert len(r.stdout.strip()) > 0
