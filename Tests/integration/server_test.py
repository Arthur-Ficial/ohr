"""Server endpoint tests for ohr."""

import httpx


# --- Health ---


class TestHealth:
    def test_health_returns_ok(self, base_url):
        r = httpx.get(f"{base_url}/health")
        assert r.status_code == 200
        data = r.json()
        assert data["status"] == "ok"
        assert data["model"] == "apple-speechanalyzer"
        assert data["model_available"] is True

    def test_health_has_version(self, base_url):
        r = httpx.get(f"{base_url}/health")
        data = r.json()
        assert "version" in data

    def test_health_has_supported_formats(self, base_url):
        r = httpx.get(f"{base_url}/health")
        data = r.json()
        assert "supported_formats" in data
        assert "m4a" in data["supported_formats"]
        assert "wav" in data["supported_formats"]

    def test_health_has_languages(self, base_url):
        r = httpx.get(f"{base_url}/health")
        data = r.json()
        assert "supported_languages" in data
        assert len(data["supported_languages"]) > 0


# --- Models ---


class TestModels:
    def test_models_returns_list(self, base_url, auth_headers):
        r = httpx.get(f"{base_url}/v1/models", headers=auth_headers)
        assert r.status_code == 200
        data = r.json()
        assert data["object"] == "list"
        assert len(data["data"]) == 1
        model = data["data"][0]
        assert model["id"] == "apple-speechanalyzer"
        assert model["owned_by"] == "apple"


# --- Transcription ---


class TestTranscription:
    def test_json_format(self, base_url, auth_headers, test_audio_m4a):
        with open(test_audio_m4a, "rb") as f:
            r = httpx.post(
                f"{base_url}/v1/audio/transcriptions",
                headers=auth_headers,
                files={"file": ("test.m4a", f, "audio/x-m4a")},
                data={"model": "apple-speechanalyzer"},
                timeout=30,
            )
        assert r.status_code == 200
        data = r.json()
        assert "text" in data
        assert len(data["text"]) > 0

    def test_verbose_json_format(self, base_url, auth_headers, test_audio_m4a):
        with open(test_audio_m4a, "rb") as f:
            r = httpx.post(
                f"{base_url}/v1/audio/transcriptions",
                headers=auth_headers,
                files={"file": ("test.m4a", f, "audio/x-m4a")},
                data={"model": "apple-speechanalyzer", "response_format": "verbose_json"},
                timeout=30,
            )
        assert r.status_code == 200
        data = r.json()
        assert data["task"] == "transcribe"
        assert "language" in data
        assert "duration" in data
        assert "segments" in data
        assert len(data["segments"]) > 0
        seg = data["segments"][0]
        assert "start" in seg
        assert "end" in seg
        assert "text" in seg

    def test_text_format(self, base_url, auth_headers, test_audio_m4a):
        with open(test_audio_m4a, "rb") as f:
            r = httpx.post(
                f"{base_url}/v1/audio/transcriptions",
                headers=auth_headers,
                files={"file": ("test.m4a", f, "audio/x-m4a")},
                data={"model": "apple-speechanalyzer", "response_format": "text"},
                timeout=30,
            )
        assert r.status_code == 200
        assert r.headers["content-type"] == "text/plain"
        assert len(r.text) > 0

    def test_srt_format(self, base_url, auth_headers, test_audio_m4a):
        with open(test_audio_m4a, "rb") as f:
            r = httpx.post(
                f"{base_url}/v1/audio/transcriptions",
                headers=auth_headers,
                files={"file": ("test.m4a", f, "audio/x-m4a")},
                data={"model": "apple-speechanalyzer", "response_format": "srt"},
                timeout=30,
            )
        assert r.status_code == 200
        assert "-->" in r.text
        assert r.text.startswith("1\n")

    def test_vtt_format(self, base_url, auth_headers, test_audio_m4a):
        with open(test_audio_m4a, "rb") as f:
            r = httpx.post(
                f"{base_url}/v1/audio/transcriptions",
                headers=auth_headers,
                files={"file": ("test.m4a", f, "audio/x-m4a")},
                data={"model": "apple-speechanalyzer", "response_format": "vtt"},
                timeout=30,
            )
        assert r.status_code == 200
        assert r.headers["content-type"] == "text/vtt"
        assert r.text.startswith("WEBVTT\n")

    def test_wav_file(self, base_url, auth_headers, test_audio_wav):
        with open(test_audio_wav, "rb") as f:
            r = httpx.post(
                f"{base_url}/v1/audio/transcriptions",
                headers=auth_headers,
                files={"file": ("test.wav", f, "audio/wav")},
                data={"model": "apple-speechanalyzer"},
                timeout=30,
            )
        assert r.status_code == 200
        data = r.json()
        assert "text" in data

    def test_missing_file_returns_400(self, base_url, auth_headers):
        r = httpx.post(
            f"{base_url}/v1/audio/transcriptions",
            headers=auth_headers,
            data={"model": "apple-speechanalyzer"},
            timeout=10,
        )
        assert r.status_code == 400

    def test_invalid_response_format_returns_400(self, base_url, auth_headers, test_audio_m4a):
        with open(test_audio_m4a, "rb") as f:
            r = httpx.post(
                f"{base_url}/v1/audio/transcriptions",
                headers=auth_headers,
                files={"file": ("test.m4a", f, "audio/x-m4a")},
                data={"model": "apple-speechanalyzer", "response_format": "xml"},
                timeout=10,
            )
        assert r.status_code == 400
        data = r.json()
        assert "invalid_request_error" in data["error"]["type"]


# --- Stub endpoints ---


class TestStubs:
    def test_chat_completions_returns_501(self, base_url, auth_headers):
        r = httpx.post(
            f"{base_url}/v1/chat/completions",
            headers=auth_headers,
            json={"model": "test", "messages": []},
            timeout=10,
        )
        assert r.status_code == 501

    def test_embeddings_returns_501(self, base_url, auth_headers):
        r = httpx.post(
            f"{base_url}/v1/embeddings",
            headers=auth_headers,
            json={"model": "test", "input": "hello"},
            timeout=10,
        )
        assert r.status_code == 501
