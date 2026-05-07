#!/usr/bin/env bash
# End-to-end release: build, sign, notarize, staple, package.
# Output: dist/VoiceSnippet.app.tar.gz ready to upload.
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/make-app.sh
./scripts/notarize.sh

echo "==> packaging tarball"
tar -czf dist/VoiceSnippet.app.tar.gz -C dist VoiceSnippet.app

echo "==> done: dist/VoiceSnippet.app.tar.gz"
ls -lh dist/VoiceSnippet.app.tar.gz
