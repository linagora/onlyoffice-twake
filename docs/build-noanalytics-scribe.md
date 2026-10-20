# Build the Scribe image

How the OnlyOffice DocumentServer image that carries the Scribe addon gets
published, and how to reproduce it locally when you need to debug it.

The image is two layers: the `onlyoffice-noanalytics` base (the official 10.0 image,
which ships without analytics), then the Scribe overlay on top of it. The sdkjs,
forms and plugin sources are pinned as defaults in `scribe/build-scribe.sh`, so
nothing is passed by hand.

## Publishing (this is the normal path)

CI builds and pushes both images. Nobody needs a Harbor account, and no image is
ever built on a laptop for production.

**Cut a release.** Tagging publishes the base, then the overlay on top of it, and
only creates the GitHub release once both are on Harbor:

```bash
git tag v1.1.0 && git push origin v1.1.0
# -> onlyoffice-noanalytics:1.1.0, then onlyoffice:1.1.0-scribe
```

**Or rebuild just the overlay.** The *Publish Scribe overlay to Harbor* workflow is
dispatchable from the Actions tab. Give it the tag to publish (a date-stamped label
such as `10.0.0-noanalytics-scribe-2026-10-20.1`) and the base tag to layer onto
(defaults to `latest`, which `main` republishes on every merge). Use this when the
overlay sources have moved but the base has not.

The workflow also takes:

- `base_image`: a full image to layer onto instead of `onlyoffice-noanalytics:<base_tag>`,
  for example `onlyoffice/documentserver:10.0.0.1`.
- `twake_drive_ref`: the Twake Drive branch, tag or commit to build the plugin from,
  to publish a test image of a Twake Drive branch before it is merged. Leave it
  empty for the commit pinned in `build-scribe.sh`.

The overlay sources are pinned to immutable refs (`SDKJS_REF=v10.0.0.169` plus
`scribe/sdkjs-scribe.patch`, `TWAKE_DRIVE_REF` a Twake Drive commit), and
`build.py` is a plain concatenation, so rebuilding the same refs in the same year
yields byte-identical bundles (the license header carries the build year).
`build-scribe.sh` prints their sha256 for comparison. Keep the refs immutable: a
branch in `SDKJS_REF` or `TWAKE_DRIVE_REF` would make two builds of the same
release tag differ.

## Building locally (debugging only)

Only when you need to inspect the build itself. The result is not what gets
deployed; publish via CI.

```bash
git clone https://github.com/linagora/onlyoffice-twake.git && cd onlyoffice-twake

# arm64 emulation: the overlay's version guard is a RUN step, once per architecture
docker run --privileged --rm tonistiigi/binfmt --install arm64

IMAGE=<registry>/onlyoffice:local-scribe \
BASE_IMAGE=onlyoffice/documentserver:10.0.0.1 \
  scribe/build-scribe.sh
```

`scribe/build-scribe.sh` compiles the word bundle (Scribe patch + forms addon) and
builds the Twake Scribe plugin from Twake Drive. It **fails** if the patch does not
apply, or if the patched methods, the forms API (`AscOForm`), the plugin, or the
base build version are not as expected.

## Verify an image

```bash
docker run --rm -p 8091:80 -e JWT_ENABLED=false <image>

# in another terminal:
curl -s localhost:8091/healthcheck                                    # true
SDK=$(curl -s localhost:8091/sdkjs/word/sdk-all.js)
printf '%s' "$SDK" | grep -c GetInlineDrawings                        # 4   (Scribe patch)
printf '%s' "$SDK" | grep -c AscOForm                                 # 69  (forms addon)
for ED in documenteditor spreadsheeteditor presentationeditor pdfeditor visioeditor; do
  echo -n "$ED trackEvent="; curl -s "localhost:8091/web-apps/apps/$ED/main/code.js" | grep -c trackEvent
done                                                                  # all 0 (no analytics)
curl -s -o /dev/null -w "plugin %{http_code}\n" localhost:8091/sdkjs-plugins/twake-scribe/index.html  # 200
```

All good when: `healthcheck=true`, `GetInlineDrawings=4`, `AscOForm=69`,
`trackEvent=0` everywhere, plugin `200`.

## See also

- [`../README.md`](../README.md): the image family overview
- [`../scribe/README.md`](../scribe/README.md): Scribe overlay internals, env vars, forms addon gotcha
- [`../dist/README.md`](../dist/README.md): the multi-arch chunked push engine
