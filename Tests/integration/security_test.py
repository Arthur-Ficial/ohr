"""Security tests for ohr server — origin validation, token auth, CORS."""

import httpx


class TestTokenAuth:
    def test_no_token_rejected_on_protected_endpoint(self, base_url):
        """Requests without auth token should get 401 on protected endpoints."""
        r = httpx.post(f"{base_url}/v1/audio/transcriptions", timeout=10)
        assert r.status_code == 401
        data = r.json()
        assert data["error"]["type"] == "authentication_error"

    def test_wrong_token_rejected(self, base_url):
        """Wrong Bearer token should get 401."""
        r = httpx.post(
            f"{base_url}/v1/audio/transcriptions",
            headers={"Authorization": "Bearer wrong-token"},
            timeout=10,
        )
        assert r.status_code == 401

    def test_correct_token_accepted(self, base_url, auth_headers, test_audio_m4a):
        """Correct Bearer token should be accepted."""
        with open(test_audio_m4a, "rb") as f:
            r = httpx.post(
                f"{base_url}/v1/audio/transcriptions",
                headers=auth_headers,
                files={"file": ("test.m4a", f, "audio/x-m4a")},
                data={"model": "apple-speechanalyzer"},
                timeout=30,
            )
        assert r.status_code == 200

    def test_health_public_without_token(self, base_url):
        """Health endpoint should be accessible without token on loopback."""
        r = httpx.get(f"{base_url}/health", timeout=10)
        assert r.status_code == 200

    def test_models_requires_token(self, base_url):
        """Models endpoint should require token when token is configured."""
        r = httpx.get(f"{base_url}/v1/models", timeout=10)
        assert r.status_code == 401


class TestOriginValidation:
    def test_no_origin_allowed(self, base_url):
        """Requests without Origin header (curl, SDK) should be allowed."""
        r = httpx.get(f"{base_url}/health", timeout=10)
        assert r.status_code == 200

    def test_localhost_origin_allowed(self, base_url):
        """Requests from localhost origin should be allowed."""
        r = httpx.get(
            f"{base_url}/health",
            headers={"Origin": "http://localhost:3000"},
            timeout=10,
        )
        assert r.status_code == 200

    def test_foreign_origin_rejected(self, base_url):
        """Requests from foreign origins should be rejected."""
        r = httpx.get(
            f"{base_url}/health",
            headers={"Origin": "http://evil.com"},
            timeout=10,
        )
        assert r.status_code == 403

    def test_subdomain_attack_rejected(self, base_url):
        """Subdomain attacks like localhost.evil.com should be rejected."""
        r = httpx.get(
            f"{base_url}/health",
            headers={"Origin": "http://localhost.evil.com"},
            timeout=10,
        )
        assert r.status_code == 403


class TestCORS:
    def test_options_preflight(self, base_url):
        """OPTIONS requests should get a 204 response."""
        r = httpx.options(
            f"{base_url}/v1/audio/transcriptions",
            headers={"Origin": "http://localhost:3000"},
            timeout=10,
        )
        assert r.status_code == 204
