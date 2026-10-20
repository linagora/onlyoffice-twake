# Scribe-patched OnlyOffice images

Layers the Scribe editor addon onto an OnlyOffice 10.0 base image:

- a patched sdkjs word bundle (`sdk-all.js` + `sdk-all-min.js`), compiled from
  upstream [ONLYOFFICE/sdkjs](https://github.com/ONLYOFFICE/sdkjs) `v10.0.0.169`
  with `sdkjs-scribe.patch` applied, plus the
  [ONLYOFFICE/sdkjs-forms](https://github.com/ONLYOFFICE/sdkjs-forms) addon
  (`v10.0.0.169`, the Word forms API `AscOForm.*`), and
- the Twake Scribe plugin (`sdkjs-plugins/twake-scribe`), from
  [linagora/twake-drive](https://github.com/linagora/twake-drive)
  (`plugins/onlyoffice-scribe`). It lets Twake Drive give the selected text of a
  text document or a presentation to its AI assistant, and write the answers back.

`sdkjs-scribe.patch` adds `ApiRun.GetInlineDrawings`, `Api.GetSelectionScreenRect`
and the `onSelectionGeometryChanged` plugin event.

`build-scribe.sh` clones the sdkjs ref and applies the patch, builds the word
bundle from it (via the vendored `sdkjs.Dockerfile.build`, a pure-Python
`build/build.py` run, no npm or JRE, that also merges the `sdkjs-forms` addon),
builds the plugin at the pinned Twake Drive commit with Twake Drive's own
`build.mjs` (in a `node:24-slim` container, with only `marked`, the Markdown reader
the plugin imports, installed), assembles the overlay context, and hands off to
[`../dist/push-multiarch.sh`](../dist/) to build and push multi-arch.

Both bundle files ship together. The stock 10.0 pair is closure-compiled, with
internal names renamed across `sdk-all.js` and `sdk-all-min.js`, so a rebuilt
`sdk-all.js` does not work next to the stock `sdk-all-min.js`.

> **Forms addon gotcha.** `build.py` resolves a relative `--addon` against
> `ROOT_DIR/..`; a path that doesn't resolve there is **silently ignored** (no
> error), yielding a forms-less bundle (`AscOForm` = 3 instead of ~69). The
> vendored Dockerfile clones the addon to an absolute path and asserts
> `AscOForm ≥ 60`; `build-scribe.sh` re-checks it on the extracted bundle.

## Version lock

The compiled bundle is locked to OnlyOffice build **`10.0.0-169`** (the
`onlyoffice/documentserver:10.0.0.1` tag). A `RUN` guard in the Dockerfile fails
the build on any other base, because a version-mismatched bundle breaks the editor.
That `RUN` executes per arch, so arm64 needs emulation:

```bash
docker run --privileged --rm tonistiigi/binfmt --install arm64
```

To move to another OnlyOffice build, bump `SDKJS_REF`, `FORMS_REF` and
`EXPECT_OO_VERSION` together, and rebase `sdkjs-scribe.patch` if it no longer
applies (`build-scribe.sh` stops when it doesn't).

## Build

Publishing goes through CI, which holds the Harbor credentials: tag a release, or
dispatch *Publish Scribe overlay to Harbor* from the Actions tab. See
[`../docs/build-noanalytics-scribe.md`](../docs/build-noanalytics-scribe.md).

Locally, to debug the build itself:

```bash
IMAGE=<registry>/onlyoffice:local-scribe \
BASE_IMAGE=onlyoffice/documentserver:10.0.0.1 \
  scribe/build-scribe.sh
```

Environment:

- `IMAGE` (required): target `repo:tag`
- `BASE_IMAGE` (required): foundation image, build `10.0.0-169`
- `TWAKE_DRIVE_REF` (default: a pinned commit): Twake Drive ref the plugin is built
  from (commit, tag or branch)
- `TWAKE_DRIVE_REPO` (default `linagora/twake-drive`): plugin source repo
- `SDKJS_REF` (default `v10.0.0.169`): sdkjs tag the patch applies to
- `SDKJS_REPO` (default `ONLYOFFICE/sdkjs`): sdkjs source repo
- `FORMS_REF` (default `v10.0.0.169`): `sdkjs-forms` addon tag, must match the
  OnlyOffice build
- `FORMS_REPO` (default `ONLYOFFICE/sdkjs-forms`): forms addon source repo
- `EXPECT_OO_VERSION` (default `10.0.0-169`): version guard value

`build-scribe.sh` checks that the patched methods and the forms API are in
`sdk-all.js`, and that the plugin is the Twake Scribe one with its Markdown reader,
before baking. The Document Server serves its plugins under a path that changes
when it starts, so a new image needs no cache-bust stamp.

## Smoke test

```bash
docker run --rm -p 8090:80 -e JWT_ENABLED=false <image>
curl -s localhost:8090/healthcheck                                   # true
SDK=$(curl -s localhost:8090/sdkjs/word/sdk-all.js)
printf '%s' "$SDK" | grep -c GetInlineDrawings                       # 4  (Scribe patch)
printf '%s' "$SDK" | grep -c AscOForm                                # 69 (forms addon)
curl -s localhost:8090/sdkjs-plugins/twake-scribe/config.json | grep -c E4B4F030   # 1 (Twake Scribe)
```

The plugin is served at `/sdkjs-plugins/twake-scribe/`; OnlyOffice discovers it from
the directory alone (no registration step).
