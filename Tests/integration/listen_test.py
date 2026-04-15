"""--listen regression test for issue #1.

Pre-fix, `ohr --listen` trapped (SIGTRAP, exit 133) inside the Speech
framework within a few seconds because the audio buffers weren't being
converted to the format SpeechTranscriber expects. Post-fix, the
process stays alive until a signal arrives.

This test launches `ohr --listen --json`, waits a handful of seconds,
and asserts the process is still running (or exited cleanly via
signal) — not trapped.

https://github.com/Arthur-Ficial/ohr/issues/1
"""

import signal
import subprocess
import time

LIVE_SECONDS = 5
SIGTRAP_EXIT_CODE = 133  # 128 + SIGTRAP (5)


class TestListenDoesNotCrash:
    def test_listen_does_not_sigtrap(self, ohr_binary):
        proc = subprocess.Popen(
            [ohr_binary, "--listen", "--json"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        # Give Speech enough time to exhibit the pre-fix crash.
        time.sleep(LIVE_SECONDS)

        if proc.poll() is None:
            # Still running — the normal, expected state.
            proc.send_signal(signal.SIGINT)
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
            return

        # Already exited — must not be SIGTRAP.
        stderr_bytes = proc.stderr.read() if proc.stderr is not None else b""
        stderr = stderr_bytes.decode("utf-8", errors="replace")
        assert proc.returncode != SIGTRAP_EXIT_CODE, (
            "ohr --listen SIGTRAP'd (exit 133) within "
            f"{LIVE_SECONDS}s. Regression of issue #1. "
            f"stderr:\n{stderr}"
        )
