#!/usr/bin/env bash

set -euo pipefail

version=""
sha256=""
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      version="${2:-}"
      shift 2
      ;;
    --sha256)
      sha256="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
      shift 2
      ;;
    *)
      echo "usage: $0 --version <version> --sha256 <sha256> --output <path>" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$version" || -z "$sha256" || -z "$output" ]]; then
  echo "usage: $0 --version <version> --sha256 <sha256> --output <path>" >&2
  exit 1
fi

cat > "$output" <<EOF
class Ohr < Formula
  desc "On-device speech-to-text CLI and OpenAI-compatible transcription server"
  homepage "https://github.com/Arthur-Ficial/ohr"
  url "https://github.com/Arthur-Ficial/ohr/releases/download/v${version}/ohr-${version}-arm64-macos.tar.gz"
  sha256 "${sha256}"
  license "MIT"

  def install
    odie "ohr requires Apple Silicon." unless Hardware::CPU.arm?

    bin.install "ohr"
  end

  def caveats
    <<~EOS
      ohr runs entirely on-device and requires macOS 26+ with Apple Silicon.

      Check model availability with:
        ohr --model-info
    EOS
  end

  test do
    assert_match "ohr ${version}", shell_output("#{bin}/ohr --version")
  end
end
EOF
