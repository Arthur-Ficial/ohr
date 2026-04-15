"""Info.plist tests — verify TCC usage descriptions are embedded.

Without NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription
embedded in the binary's __TEXT,__info_plist section, macOS aborts (SIGTRAP,
exit 133) the first time the process touches the microphone or speech APIs.

This test fails if the required keys are missing from either:
  - the source Info.plist on disk, or
  - the compiled binary's embedded Info.plist.

Regression: https://github.com/Arthur-Ficial/ohr/issues/1
"""

import os
import plistlib
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SOURCE_INFO_PLIST = REPO_ROOT / "Info.plist"

REQUIRED_KEYS = [
    "NSMicrophoneUsageDescription",
    "NSSpeechRecognitionUsageDescription",
]


class TestSourceInfoPlist:
    def test_info_plist_exists(self):
        assert SOURCE_INFO_PLIST.is_file(), f"missing {SOURCE_INFO_PLIST}"

    @pytest.mark.parametrize("key", REQUIRED_KEYS)
    def test_required_key_present(self, key):
        with SOURCE_INFO_PLIST.open("rb") as f:
            plist = plistlib.load(f)
        assert key in plist, f"{SOURCE_INFO_PLIST} is missing {key}"
        assert plist[key].strip(), f"{key} must be a non-empty description"


class TestEmbeddedInfoPlist:
    """Verify the compiled binary has the keys embedded (issue #1 root cause)."""

    def test_binary_has_required_keys(self, ohr_binary):
        path = ohr_binary
        if not os.path.isabs(path):
            # PATH lookup for local/installed binary
            which = subprocess.run(
                ["which", path], capture_output=True, text=True
            )
            if which.returncode != 0:
                pytest.skip(f"binary not found on PATH: {path}")
            path = which.stdout.strip()

        out = subprocess.run(
            ["strings", path],
            capture_output=True,
            text=True,
            check=True,
        )
        for key in REQUIRED_KEYS:
            assert (
                key in out.stdout
            ), f"compiled binary {path} is missing embedded {key}"
