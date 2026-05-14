#!/usr/bin/env bash
# Publish the @shoulderdev/cli npm packages for a given release tag.
#
# Downloads binaries + SHA256SUMS.txt from shoulderdev/binaries for the tag,
# verifies checksums, stages each platform's binary under
# cli-packages/npm-<os>-<arch>/vendor/, rewrites package.json versions, and
# `npm publish`es each platform package followed by the launcher.
#
# Usage:
#   scripts/publish.sh <tag> [--dry-run]
#
# Examples:
#   scripts/publish.sh v0.1.0
#   scripts/publish.sh v0.1.0 --dry-run

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <tag> [--dry-run]" >&2
  exit 2
fi

TAG="$1"
DRY_RUN=0
if [[ "${2:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "error: tag '$TAG' must look like vX.Y.Z[-prerelease]" >&2
  exit 2
fi

VERSION="${TAG#v}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_REPO="shoulderdev/binaries"

# Platform table: <npm-os-arch>:<binary-suffix>
# binary-suffix is the GOOS-GOARCH form used in the release asset filename.
PLATFORMS=(
  "linux-x64:linux-amd64"
  "linux-arm64:linux-arm64"
  "darwin-x64:darwin-amd64"
  "darwin-arm64:darwin-arm64"
  "win32-x64:windows-amd64.exe"
  "win32-arm64:windows-arm64.exe"
)

for tool in jq curl shasum gh node; do
  command -v "$tool" >/dev/null 2>&1 || { echo "error: required tool '$tool' not on PATH" >&2; exit 1; }
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
echo "==> scratch dir: $WORK"

# --- 1. Fetch checksums ---------------------------------------------------
echo "==> downloading SHA256SUMS.txt for $TAG"
gh release download "$TAG" \
  --repo "$RELEASE_REPO" \
  --pattern "SHA256SUMS.txt" \
  --dir "$WORK"

CHECKSUMS="$WORK/SHA256SUMS.txt"
[[ -s "$CHECKSUMS" ]] || { echo "error: SHA256SUMS.txt is empty or missing" >&2; exit 1; }

verify_sha256() {
  local file="$1" basename
  basename="$(basename "$file")"
  local expected
  expected="$(awk -v f="$basename" '$2 == f { print $1 }' "$CHECKSUMS")"
  if [[ -z "$expected" ]]; then
    echo "error: no SHA256 entry for $basename in SHA256SUMS.txt" >&2
    return 1
  fi
  local actual
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "error: checksum mismatch for $basename" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    return 1
  fi
}

# --- 2. Download + stage per-platform binaries ----------------------------
for entry in "${PLATFORMS[@]}"; do
  npm_key="${entry%%:*}"
  go_suffix="${entry##*:}"
  asset="shoulder-${go_suffix}"
  pkg_dir="$ROOT/npm-${npm_key}"
  vendor_dir="$pkg_dir/vendor"

  [[ -d "$pkg_dir" ]] || { echo "error: missing $pkg_dir" >&2; exit 1; }

  echo "==> [$npm_key] downloading $asset"
  gh release download "$TAG" \
    --repo "$RELEASE_REPO" \
    --pattern "$asset" \
    --dir "$WORK" \
    --clobber

  echo "==> [$npm_key] verifying SHA256"
  verify_sha256 "$WORK/$asset"

  # Bin name inside the package: shoulder or shoulder.exe
  if [[ "$npm_key" == win32-* ]]; then
    bin_name="shoulder.exe"
  else
    bin_name="shoulder"
  fi

  rm -f "$vendor_dir"/shoulder "$vendor_dir"/shoulder.exe "$vendor_dir"/.gitkeep
  install -m 0755 "$WORK/$asset" "$vendor_dir/$bin_name"
  echo "==> [$npm_key] staged $vendor_dir/$bin_name"

  # Rewrite version in package.json
  pkg_json="$pkg_dir/package.json"
  new_version="${VERSION}-${npm_key}"
  tmp="$(mktemp)"
  jq --arg v "$new_version" '.version = $v' "$pkg_json" > "$tmp"
  mv "$tmp" "$pkg_json"
  echo "==> [$npm_key] version → $new_version"
done

# --- 3. Rewrite launcher package.json -------------------------------------
LAUNCHER="$ROOT/npm/package.json"
tmp="$(mktemp)"
jq --arg v "$VERSION" '
  .version = $v
  | .optionalDependencies = (
      .optionalDependencies
      | to_entries
      | map(
          .key as $k
          | ($k | sub("^@shoulderdev/cli-"; "")) as $suffix
          | .value = ("npm:@shoulderdev/cli@" + $v + "-" + $suffix)
        )
      | from_entries
    )
' "$LAUNCHER" > "$tmp"
mv "$tmp" "$LAUNCHER"
echo "==> launcher version → $VERSION"

# --- 4. Pre-publish: verify tarball contents against an allowlist ---------
# Fails the run if any package would ship a file outside the expected set.
# Defense in depth against accidental source leakage.
LAUNCHER_ALLOW=("README.md" "bin/shoulder.js" "package.json")
PLATFORM_ALLOW_UNIX=("package.json" "vendor/shoulder")
PLATFORM_ALLOW_WIN=("package.json" "vendor/shoulder.exe")

verify_tarball_contents() {
  local dir="$1"; shift
  local allowed=("$@")
  local actual
  actual="$(cd "$dir" && npm pack --dry-run --json 2>/dev/null | jq -r '.[0].files[].path' | sort)"
  local expected
  expected="$(printf '%s\n' "${allowed[@]}" | sort)"
  if [[ "$actual" != "$expected" ]]; then
    echo "error: $dir would publish unexpected files." >&2
    echo "  actual:" >&2;   printf '    %s\n' $actual   >&2
    echo "  expected:" >&2; printf '    %s\n' $expected >&2
    return 1
  fi
}

for entry in "${PLATFORMS[@]}"; do
  npm_key="${entry%%:*}"
  if [[ "$npm_key" == win32-* ]]; then
    verify_tarball_contents "$ROOT/npm-${npm_key}" "${PLATFORM_ALLOW_WIN[@]}"
  else
    verify_tarball_contents "$ROOT/npm-${npm_key}" "${PLATFORM_ALLOW_UNIX[@]}"
  fi
done
verify_tarball_contents "$ROOT/npm" "${LAUNCHER_ALLOW[@]}"
echo "==> tarball contents verified against allowlist"

# --- 5. Publish (platform packages first, launcher last) ------------------
#
# Each platform version (e.g. `0.0.1-linux-x64`) is a SemVer prerelease.
# npm 11+ refuses to publish a prerelease without an explicit `--tag`
# because the default would be `latest` and a user running
# `npm install @shoulderdev/cli` would land on a platform-specific
# tarball instead of the launcher. Give each platform its own dist-tag
# (purely cosmetic — `optionalDependencies` references them by exact
# version, never by tag) and reserve `latest` for the launcher.
publish_pkg() {
  local dir="$1" tag="$2" name version
  name="$(jq -r .name "$dir/package.json")"
  version="$(jq -r .version "$dir/package.json")"
  echo "==> publishing ${name}@${version} (tag=${tag}) from $dir"
  if [[ "$DRY_RUN" == "1" ]]; then
    (cd "$dir" && npm publish --dry-run --access public --provenance --tag "$tag")
  else
    (cd "$dir" && npm publish --access public --provenance --tag "$tag")
  fi
}

for entry in "${PLATFORMS[@]}"; do
  npm_key="${entry%%:*}"
  publish_pkg "$ROOT/npm-${npm_key}" "platform-${npm_key}"
done

publish_pkg "$ROOT/npm" "latest"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "==> dry-run complete; nothing was published"
else
  echo "==> published @shoulderdev/cli@${VERSION} + 6 platform variants"
fi
