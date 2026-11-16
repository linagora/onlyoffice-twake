#!/usr/bin/env bash
# Build a multi-arch Scribe OnlyOffice image.
#
# Builds the Twake Scribe plugin of Twake Drive at a pinned git ref, then hands the
# overlay context to ../dist/push-multiarch.sh, which builds amd64+arm64 and pushes
# a single multi-arch tag (resilient to harbor.linagora.com's upload resets).
#
# The BASE_IMAGE picks the foundation:
#   • onlyoffice/documentserver:9.4.0.1                 -> stock + Scribe
#   • <registry>/twake-workplace/onlyoffice:9.4.0-noanalytics -> analytics-free + Scribe
#
# Prerequisites: docker login <registry>.
#
# Usage:
#   IMAGE=<repo:tag> BASE_IMAGE=<oo-image> ./scribe/build-scribe.sh
#
# Overridable via env: TWAKE_DRIVE_REF/TWAKE_DRIVE_REPO (plugin git ref/repo).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMAGE="${IMAGE:?Set IMAGE, e.g. harbor.example.com/twake-workplace/onlyoffice:9.4.0.1-scribe-2026-07-22.3}"
BASE_IMAGE="${BASE_IMAGE:?Set BASE_IMAGE, e.g. onlyoffice/documentserver:9.4.0.1}"

# The Twake Scribe plugin lives in Twake Drive (plugins/onlyoffice-scribe), which
# builds it with its Markdown reader. A commit keeps a release reproducible; a
# branch or a tag works too, for a test image.
TWAKE_DRIVE_REPO="${TWAKE_DRIVE_REPO:-https://github.com/linagora/twake-drive.git}"
TWAKE_DRIVE_REF="${TWAKE_DRIVE_REF:-cf4a3e18dc53d0eb1fe234fef718f403ff700790}"
TWAKE_SCRIBE_GUID='asc.{E4B4F030-94E5-48BE-A962-A6E87CB6262B}'

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
CTX="$WORK/ctx"; mkdir -p "$CTX"

# 1. Twake Scribe plugin at the pinned ref -> $CTX/twake-scribe. Twake Drive builds
#    it with plugins/onlyoffice-scribe/build.mjs, which adds the Markdown reader it
#    imports (marked): only marked is installed, at the version Twake Drive asks
#    for, not the dependencies of the whole app. Node runs in Docker. The Document
#    Server serves its plugins under a path that changes when it starts, so a new
#    image needs no cache-bust stamp.
git init -q "$WORK/drive"
git -C "$WORK/drive" remote add origin "$TWAKE_DRIVE_REPO"
git -C "$WORK/drive" sparse-checkout set plugins/onlyoffice-scribe
git -C "$WORK/drive" fetch -q --depth 1 --filter=blob:none origin "$TWAKE_DRIVE_REF" \
  || { echo "fetch of $TWAKE_DRIVE_REPO#$TWAKE_DRIVE_REF failed — is the ref pushed?" >&2; exit 1; }
git -C "$WORK/drive" checkout -q FETCH_HEAD
DRIVE_COMMIT="$(git -C "$WORK/drive" rev-parse --short=12 HEAD)"
docker run --rm -v "$WORK/drive:/src" -w /src node:24-slim sh -euc '
  npm install --silent --no-audit --no-fund --prefix /tmp/marked \
    "marked@$(node -p "require(\"./package.json\").devDependencies.marked")"
  ln -s /tmp/marked/node_modules node_modules
  node plugins/onlyoffice-scribe/build.mjs
  rm node_modules
  chown -R "$(stat -c %u:%g /src)" plugins/onlyoffice-scribe/build'
cp -a "$WORK/drive/plugins/onlyoffice-scribe/build" "$CTX/twake-scribe"
grep -qF "$TWAKE_SCRIBE_GUID" "$CTX/twake-scribe/config.json" \
  || { echo "twake-scribe/config.json is not the Twake Scribe plugin ($TWAKE_SCRIBE_GUID)" >&2; exit 1; }
[ -s "$CTX/twake-scribe/vendor/marked.esm.js" ] \
  || { echo "twake-scribe is missing its Markdown reader (vendor/marked.esm.js)" >&2; exit 1; }
echo "Twake Scribe plugin $TWAKE_DRIVE_REF ($DRIVE_COMMIT)"

# 2. Dockerfile + hand off to the shared multi-arch build/push engine.
cp "$HERE/Dockerfile" "$CTX/Dockerfile"
IMAGE="$IMAGE" CONTEXT="$CTX" BASE_IMAGE="$BASE_IMAGE" \
  "$HERE/../dist/push-multiarch.sh"
