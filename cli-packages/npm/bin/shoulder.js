#!/usr/bin/env node
// Launcher for the Shoulder CLI.
//
// At install time, npm resolves the optional dependency that matches the
// current platform/arch and unpacks its bundled binary under
// node_modules/@shoulderdev/cli-<os>-<arch>/vendor/. This script locates
// that binary, execs it, and forwards stdio, signals, and exit code.
//
// No network, no postinstall: the binary is on disk by the time this runs.

import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const require = createRequire(import.meta.url);

const { platform, arch } = process;

const SUPPORTED = {
  "linux-x64": "@shoulderdev/cli-linux-x64",
  "linux-arm64": "@shoulderdev/cli-linux-arm64",
  "darwin-x64": "@shoulderdev/cli-darwin-x64",
  "darwin-arm64": "@shoulderdev/cli-darwin-arm64",
  "win32-x64": "@shoulderdev/cli-win32-x64",
  "win32-arm64": "@shoulderdev/cli-win32-arm64",
};

const key = `${platform}-${arch}`;
const platformPackage = SUPPORTED[key];

if (!platformPackage) {
  console.error(
    `shoulder: unsupported platform ${platform}/${arch}. ` +
      `Supported: ${Object.keys(SUPPORTED).join(", ")}.`,
  );
  process.exit(1);
}

const binaryName = platform === "win32" ? "shoulder.exe" : "shoulder";

let binaryPath;
try {
  const pkgJsonPath = require.resolve(`${platformPackage}/package.json`);
  binaryPath = path.join(path.dirname(pkgJsonPath), "vendor", binaryName);
} catch {
  // Dev fallback: allow running the launcher directly from this repo
  // against a sibling `cli-packages/npm-<os>-<arch>/vendor/<binary>`.
  const devCandidate = path.join(
    __dirname,
    "..",
    "..",
    `npm-${platform}-${arch}`,
    "vendor",
    binaryName,
  );
  if (existsSync(devCandidate)) {
    binaryPath = devCandidate;
  } else {
    console.error(
      `shoulder: missing optional dependency ${platformPackage}.\n` +
        `Reinstall: npm install -g @shoulderdev/cli@latest`,
    );
    process.exit(1);
  }
}

if (!existsSync(binaryPath)) {
  console.error(`shoulder: expected binary at ${binaryPath} but it is missing.`);
  process.exit(1);
}

const child = spawn(binaryPath, process.argv.slice(2), { stdio: "inherit" });

child.on("error", (err) => {
  console.error(`shoulder: failed to exec ${binaryPath}: ${err.message}`);
  process.exit(1);
});

const forward = (signal) => {
  if (!child.killed) {
    try {
      child.kill(signal);
    } catch {
      /* ignore */
    }
  }
};
for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(sig, () => forward(sig));
}

child.on("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
  } else {
    process.exit(code ?? 1);
  }
});
