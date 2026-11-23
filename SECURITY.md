# Security Policy

## Supported versions

Only the latest tagged release receives fixes. Pre-release builds (`0.x`) are development snapshots.

## Reporting a vulnerability

Do **not** open a public issue. Use GitHub's private vulnerability reporting on this repository
(**Security → Report a vulnerability**), or contact **JoeyHammoth** directly. You should get an answer within a
week. Please include the game version, mod version, and steps to reproduce.

## What counts as a security issue here

This is a single-player game mod, so the realistic attack surface is the repository and its automation, not the
mod's gameplay logic:

- **Leaked credentials.** CI tokens, Steam credentials, or a `GH_TOKEN` committed to the repo or embedded in a
  workflow log.
- **The self-hosted runner.** `validate.yml` runs on a machine with CK3 installed and a GitHub token. A workflow
  that lets fork pull requests execute arbitrary code there is a serious vulnerability. Report any change that
  loosens the trigger conditions.
- **Malicious release artifacts.** Anything that gets a modified zip into a GitHub Release or the Steam Workshop
  without passing the review process.
- **Save-game handling.** A path or parser bug that would let a crafted save write outside the expected
  directories.

Ordinary balance bugs, crashes and compatibility problems are **not** security issues — use the bug report form.

## Practices this repo follows

- No vanilla game files are stored in the repository (copyright, and it keeps the repo publishable).
- Tokens live in `.env` locally and in Actions secrets in CI; `.env` is git-ignored.
- The heavy validator job runs only on `push` to protected branches and on manual dispatch, never on fork PRs.
- Releases are built by `.github/workflows/release.yml` from a tag, and the zip's contents are limited to
  `mod/`.
- Workflow permissions are least-privilege: `contents: read` unless a job genuinely needs to write.

If you see a workflow or script that breaks one of these, that is a reportable bug even if nothing has been
exploited yet.
