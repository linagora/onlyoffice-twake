# OnlyOffice DocumentServer images for Twake

Multi-arch builds of **OnlyOffice DocumentServer 10.0** (build `10.0.0-169`),
published to Harbor under the `twake-workplace` project:

- `onlyoffice-noanalytics:<version>`: the official `onlyoffice/documentserver:10.0.0.1`
  image, mirrored to Harbor. Upstream removed Google Analytics from the editors in
  10.0, so it needs no patch of ours.
- `onlyoffice:<version>-scribe`: the same image with the Scribe addon layered on
  top (a patched `sdkjs` word bundle and the Twake Scribe plugin of Twake Drive).

Every image is `linux/amd64` + `linux/arm64`.

## How it works

The official image installs a prebuilt `.deb` with the editors deployed under
`/var/www/onlyoffice/documentserver/`. Scribe is a thin overlay on that image
(`scribe/`):

- the word bundle (`sdk-all.js` + `sdk-all-min.js`) rebuilt from upstream `sdkjs`
  `v10.0.0.169` with `scribe/sdkjs-scribe.patch` applied, and
- the Twake Scribe plugin (`sdkjs-plugins/twake-scribe`).

The patch is version-locked to build `10.0.0-169`, and a build guard enforces it.
See [`scribe/README.md`](scribe/README.md).

## Publishing

CI holds the Harbor credentials and pushes every image. A release tag publishes the
base and then the Scribe overlay on top of it:

```bash
git tag v1.1.0 && git push origin v1.1.0   # -> onlyoffice-noanalytics:1.1.0
                                           # -> onlyoffice:1.1.0-scribe
```

The tag must match `v[0-9]+.[0-9]+.[0-9]+*`. The image tag is the git tag without
the leading `v`, and a GitHub release opens once both images are on Harbor.

Merging to `main` republishes `onlyoffice-noanalytics:latest` and
`onlyoffice:latest`. The Scribe overlay can also be rebuilt on its own from the
Actions tab (*Publish Scribe overlay to Harbor*); see
[`docs/build-noanalytics-scribe.md`](docs/build-noanalytics-scribe.md).

CI needs four repository secrets: `HARBOR_REGISTRY`, `HARBOR_USER`,
`HARBOR_PASSWORD`, `HARBOR_PROJECT`.

## Building locally

To debug a build. Publishing goes through CI.

```bash
docker run --privileged --rm tonistiigi/binfmt --install arm64   # arm64 emulation, once

IMAGE=<registry>/onlyoffice:local-scribe \
BASE_IMAGE=onlyoffice/documentserver:10.0.0.1 \
  scribe/build-scribe.sh
```

`dist/push-multiarch.sh` is the multi-arch push engine both builds use, including
how it gets past Harbor resetting large blob uploads; see
[`dist/README.md`](dist/README.md).

## Repo layout

- `dist/`: the `onlyoffice-noanalytics` base (`Dockerfile`) and the multi-arch push
  engine (`push-multiarch.sh`)
- `scribe/`: the Scribe overlay (`Dockerfile`, `build-scribe.sh`, `sdkjs-scribe.patch`)
- `.github/workflows/`: build on PR, publish `latest` on `main`, publish a version on
  a `v*` tag
