"""Shared fixtures for ohr integration tests."""

import os
import subprocess
import tempfile

import pytest


@pytest.fixture
def base_url():
    port = os.environ.get("OHR_TEST_PORT", "11436")
    return f"http://localhost:{port}"


@pytest.fixture
def token():
    return os.environ.get("OHR_TEST_TOKEN", "test-integration-token")


@pytest.fixture
def auth_headers(token):
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def ohr_binary():
    return os.environ.get("OHR_TEST_BINARY", "ohr")


@pytest.fixture
def test_audio_m4a():
    """Generate a short M4A test audio file using macOS say command."""
    with tempfile.NamedTemporaryFile(suffix=".m4a", delete=False) as f:
        path = f.name
    subprocess.run(
        ["say", "-o", path, "Hello world. Testing one two three."],
        check=True,
        capture_output=True,
    )
    yield path
    os.unlink(path)


@pytest.fixture
def test_audio_wav():
    """Generate a short WAV test audio file."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    subprocess.run(
        ["say", "-o", path, "--data-format=LEI16@44100", "The quick brown fox."],
        check=True,
        capture_output=True,
    )
    yield path
    os.unlink(path)
