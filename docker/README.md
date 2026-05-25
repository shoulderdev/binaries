# Shoulder CLI — Docker image

[Shoulder](https://shoulder.dev) is a local-first trust scanner for developers and AI coding agents.

> Is this code, dependency, or release safe to trust right now?

The official container image lives at `ghcr.io/shoulderdev/cli` and is published from this repository on every release.

## Pull

```sh
docker pull ghcr.io/shoulderdev/cli:latest
# or pin to a specific release
docker pull ghcr.io/shoulderdev/cli:v0.0.3
```

## Usage

The image's entrypoint is `shoulder`, so any CLI argument can be passed directly:

```sh
docker run --rm ghcr.io/shoulderdev/cli --help
docker run --rm ghcr.io/shoulderdev/cli version
```

To scan code on your host, mount the project directory and run `trust` against the mount point:

```sh
docker run --rm -v "$PWD:/src" -w /src ghcr.io/shoulderdev/cli trust .
docker run --rm -v "$PWD:/src" -w /src ghcr.io/shoulderdev/cli trust diff
```

Vet a package before installing it:

```sh
docker run --rm ghcr.io/shoulderdev/cli trust deps <package>@<version>
```

## Tags

| Tag              | Updated on            |
| ---------------- | --------------------- |
| `latest`         | Every stable release  |
| `vX.Y.Z`         | The matching release  |
| `vX.Y.Z-rc.N`    | Prerelease tags only  |

Prerelease tags (`-rc.*`, `-beta.*`, `-alpha.*`) do **not** move `:latest`.

## Supported platforms

The image is multi-arch — Docker will pull the right variant automatically:

| OS    | Architectures |
| ----- | ------------- |
| Linux | amd64, arm64  |

## Verify the image

Each image is signed at push time by [cosign](https://github.com/sigstore/cosign) using keyless Sigstore signatures tied to this repository's GitHub Actions OIDC identity. Verify by digest:

```sh
DIGEST=$(docker buildx imagetools inspect ghcr.io/shoulderdev/cli:latest \
  --format '{{.Manifest.Digest}}')

cosign verify "ghcr.io/shoulderdev/cli@${DIGEST}" \
  --certificate-identity-regexp 'https://github.com/shoulderdev/binaries' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

A successful verification confirms the image was built and pushed by the `publish-docker` workflow in `shoulderdev/binaries`, not by any other source.

## What's inside

- Base: `alpine:3.21`
- Tools: `git`, `ca-certificates`, `curl`
- Entrypoint: `/usr/local/bin/shoulder` — byte-identical to the matching `shoulder-linux-<arch>` release asset published in this repository

The image does not bundle any analyzer source code; it ships the same signed CLI binary you would download directly from the release page.

## Links

- Website: <https://shoulder.dev>
- Binaries + checksums: <https://github.com/shoulderdev/binaries/releases>
- Image source / build workflow: [.github/workflows/publish-docker.yml](../.github/workflows/publish-docker.yml)
- Feedback / issues: <https://github.com/shoulderdev/feedback/issues>
