# Scribe OnlyOffice images

Layers the Twake Scribe plugin (`sdkjs-plugins/twake-scribe`) onto an OnlyOffice
base image. The plugin comes from
[linagora/twake-drive](https://github.com/linagora/twake-drive)
(`plugins/onlyoffice-scribe`): it lets Twake Drive give the selected text of a
document to its AI assistant, and write the answers back. It runs on the stock
editor API, so the image replaces no sdkjs bundle.

`build-scribe.sh` builds the plugin at the pinned Twake Drive commit with Twake
Drive's own `build.mjs` (in a `node:24-slim` container, with only `marked`, the
Markdown reader the plugin imports, installed), assembles the overlay context, and
hands off to [`../dist/push-multiarch.sh`](../dist/) to build and push multi-arch.
The overlay Dockerfile is `Dockerfile`, COPY-only, so no arm64 emulation is needed.

## OnlyOffice version

The overlay does not check the base version. The plugin needs OnlyOffice 9.2 or
later and was tested with 9.4; in spreadsheets it also reads editor internals, and
turns itself off there when a build renames them. See
[Twake Drive's scribe doc](https://github.com/linagora/twake-drive/blob/master/docs/onlyoffice-scribe.md#when-the-button-is-shown).

## Build

Publishing goes through CI, which holds the Harbor credentials: tag a release, or
dispatch *Publish Scribe overlay to Harbor* from the Actions tab. See
[`../docs/build-noanalytics-scribe.md`](../docs/build-noanalytics-scribe.md).

Locally, to debug the build itself:

```bash
# Scribe on the analytics-free base (GA removed + Scribe):
IMAGE=onlyoffice:local-scribe \
BASE_IMAGE=harbor.linagora.com/twake-workplace/onlyoffice-noanalytics:latest \
  scribe/build-scribe.sh

# Scribe on stock OnlyOffice 9.4.0.1:
IMAGE=onlyoffice:local-scribe-stock \
BASE_IMAGE=onlyoffice/documentserver:9.4.0.1 \
  scribe/build-scribe.sh
```

Environment:

| var | default | purpose |
|-----|---------|---------|
| `IMAGE` | (required) | target `repo:tag` |
| `BASE_IMAGE` | (required) | foundation image |
| `TWAKE_DRIVE_REF` | a pinned commit | Twake Drive ref the plugin is built from (commit, tag or branch) |
| `TWAKE_DRIVE_REPO` | `linagora/twake-drive` | plugin source repo |

`build-scribe.sh` checks that the plugin is the Twake Scribe one with its Markdown
reader before baking. The Document Server serves its plugins under a path that
changes when it starts, so a new image needs no cache-bust stamp.

## Smoke test

```bash
docker run --rm -p 8090:80 -e JWT_ENABLED=false <image>
curl -s localhost:8090/healthcheck                                   # true
curl -s localhost:8090/sdkjs-plugins/twake-scribe/config.json | grep -c E4B4F030   # 1 (Twake Scribe)
```

The plugin is served at `/sdkjs-plugins/twake-scribe/`; OnlyOffice discovers it from
the directory alone (no registration step). On the analytics-free base the editor
bundles keep `trackEvent=0`; on the stock base they retain upstream analytics.
