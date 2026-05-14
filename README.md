# Shoulder.dev Binaries

This repository hosts the public release binaries for Shoulder.

Shoulder is a local-first trust scanner for developers and AI coding agents. It answers a practical shipping question: **is this code, dependency, or release safe to trust right now?** Results include a verdict, supporting evidence, and a blast-radius summary that a human reviewer or agent can act on.

Learn more at [shoulder.dev](https://shoulder.dev).

## What's Here

Release assets in this repository include:

- Platform-specific Shoulder CLI binaries
- Checksums and SBOMs

## Shoulder CLI

The Shoulder CLI is designed for local use in developer workflows:

- Run trust checks before committing, merging, or shipping code
- Compare trust drift between a branch, commit, or working tree
- Vet packages before an install
- Connect Shoulder to AI coding tools and editor workflows

Your code is analyzed locally. Dependency and package intelligence may use Shoulder ecosystem services when a verdict requires current supply-chain context.

## Verification

Use the published checksums for each release artifact before running a downloaded binary.

```sh
shasum -a 256 <downloaded-binary>
```

Compare the output with the checksum published alongside the release.

## More Information

- Website: [shoulder.dev](https://shoulder.dev)
- Feedback: [shoulder.dev](https://shoulder.dev/feedback)