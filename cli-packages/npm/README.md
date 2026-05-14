# @shoulderdev/cli

[Shoulder](https://shoulder.dev) is a local-first trust scanner for developers and AI coding agents.

> Is this code, dependency, or release safe to trust right now?

## Install

```sh
npm install -g @shoulderdev/cli
```

The right native binary for your platform is installed automatically via npm's `optionalDependencies` — no postinstall scripts, no network calls at install time.

## Usage

```sh
shoulder --help
shoulder trust .
shoulder trust diff
shoulder trust deps <package>@<version>
```

## Supported platforms

| OS      | Architectures |
| ------- | ------------- |
| Linux   | x64, arm64    |
| macOS   | x64, arm64    |
| Windows | x64, arm64    |

## Verify the binary

Each release is published with SHA-256 checksums and SBOMs at
<https://github.com/shoulderdev/binaries>. The npm-shipped binary is byte-identical to the matching GitHub release asset.

## Links

- Website: <https://shoulder.dev>
- Binaries + checksums: <https://github.com/shoulderdev/binaries>
- Feedback / issues: <https://github.com/shoulderdev/feedback/issues>
