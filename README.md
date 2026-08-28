# Varavel Container Tools

Minimal, self-published container images for CLI tools that do not ship an
official container image. Each image is a multi-stage build ending in a final
stage (from `scratch` base image) containing only the pinned upstream binary,
and everything is published to this repository's GitHub Container Registry
namespace.

These images are not intended to be run directly, but rather to be used to copy
the tools in your own `Dockerfile` using `COPY --from`, that's why all of them
use `scratch` and they really just download the binaries correctly, so you don't
have to worry about that.

## Images

| Image                                                                                                  | Upstream                                                                | Binary                                                             | Architectures                |
| ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------- | ------------------------------------------------------------------ | ---------------------------- |
| [ghcr.io/varavelio/container-tools/task](https://ghcr.io/varavelio/container-tools/task)               | [go-task/task](https://github.com/go-task/task)                         | `/usr/local/bin/task`                                              | `linux/amd64`, `linux/arm64` |
| [ghcr.io/varavelio/container-tools/goose](https://ghcr.io/varavelio/container-tools/goose)             | [pressly/goose](https://github.com/pressly/goose)                       | `/usr/local/bin/goose`                                             | `linux/amd64`, `linux/arm64` |
| [ghcr.io/varavelio/container-tools/tailwindcss](https://ghcr.io/varavelio/container-tools/tailwindcss) | [tailwindlabs/tailwindcss](https://github.com/tailwindlabs/tailwindcss) | `/usr/local/bin/tailwindcss` and `/usr/local/bin/tailwindcss-musl` | `linux/amd64`, `linux/arm64` |
| [ghcr.io/varavelio/container-tools/dprint](https://ghcr.io/varavelio/container-tools/dprint)           | [dprint/dprint](https://github.com/dprint/dprint)                       | `/usr/local/bin/dprint` and `/usr/local/bin/dprint-musl`           | `linux/amd64`, `linux/arm64` |

## Tagging policy

- Tags mirror the exact upstream release version, without the leading `v` if it
  exists (e.g. `v3.53.1` -> `3.53.1`).
- There is **no `latest` tag, by design**: consumers must always pin a version.
- Per-architecture tags (`<version>-amd64`, `<version>-arm64`) are also
  published; they are an implementation detail of the multi-arch assembly and
  are version-pinned as well.

## Automation

[`.github/workflows/images.yaml`](.github/workflows/images.yaml) runs every six
hours.

1. Asks the GitHub API for the recent stable releases of every tracked tool
   (pre-releases and drafts are ignored).
2. Compares them against the tags already published in GHCR, so runs are
   idempotent and only new versions get built.
3. Builds each missing version **natively** on amd64 and arm64 runners (no QEMU,
   no emulation) passing the upstream version and `TARGETARCH` as explicit build
   args.
4. Merges the per-architecture tags into a single multi-arch tag per version.
5. Scans every tool package in this repository's GHCR namespace and commits
   [`images.json`](images.json), an inventory of all published versions per
   tool.

Manual runs (`workflow_dispatch`) accept two optional inputs:

- `tools`: comma-separated subset of tools to consider (empty = all).
- `force`: rebuild the latest upstream version of each selected tool even if it
  is already published (useful after changing a `Dockerfile`).

## Usage

The images are intended to be used in this way in your own `Dockerfile`.

```dockerfile
FROM debian:latest

COPY --from ghcr.io/varavelio/container-tools/task:<version> /usr/local/bin/task /usr/local/bin/task
COPY --from ghcr.io/varavelio/container-tools/goose:<version> /usr/local/bin/goose /usr/local/bin/goose
COPY --from ghcr.io/varavelio/container-tools/tailwindcss:<version> /usr/local/bin/tailwindcss /usr/local/bin/tailwindcss
COPY --from ghcr.io/varavelio/container-tools/tailwindcss:<version> /usr/local/bin/tailwindcss-musl /usr/local/bin/tailwindcss
COPY --from ghcr.io/varavelio/container-tools/dprint:<version> /usr/local/bin/dprint /usr/local/bin/dprint
COPY --from ghcr.io/varavelio/container-tools/dprint:<version> /usr/local/bin/dprint-musl /usr/local/bin/dprint
```

## Adding a tool

1. Create `<name>/Dockerfile` following the existing ones: an Alpine downloader
   stage that fetches the pinned upstream release for `${TARGETARCH}`, and a
   `FROM scratch` final stage with just the binaries and OCI labels (no CA
   bundles, no entrypoints, the images are not meant to be run). The version
   must come from a `<NAME>_VERSION` build arg.
2. Add a line `<name>|<owner>/<repo>|<NAME>_VERSION>` to
   [`scripts/tools.txt`](scripts/tools.txt).
3. Add it to the table above.

## Notes

- The images have **no `ENTRYPOINT`/`CMD` on purpose**: they are not runnable,
  only pullable and copyable with `COPY --from`.
- `images.json` is regenerated and committed by the `track` job on every run; it
  only changes when the published versions change.
- New GHCR packages start private. Change the visibility of each package to
  public in its package settings if it should be consumable without login.
