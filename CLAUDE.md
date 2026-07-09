# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Homebrew third-party tap (`drod3763/tap`) hosting these packages:

- **`Formula/rar.rb`** — Formula for the RAR CLI (downloads prebuilt binaries from rarlab.com; dual-arch: ARM + Intel)
- **`Formula/truenas-mcp.rb`** — Formula for TrueNAS MCP server (builds from source via `go build`; requires Go)
- **`Formula/herdr-mx.rb`** — Formula for the herdr-mx fork (downloads prebuilt, minisign-signed binaries from GitHub Releases; dual-OS macOS + Linux, dual-arch ARM + Intel; self-update disabled by design, so updates ship through this tap)
- **`Formula/git-delta-fork.rb`** — Formula for the drod3763 delta fork (HEAD-only; builds from source via `cargo`)
- **`Casks/openin-helper.rb`** — Cask for OpenIn Helper macOS app (downloaded from loshadki.app appcast)
- **`Casks/amphetamine-power-protect.rb`** — Cask for Power Protect for Amphetamine (runs a `.pkg` from a DMG in the x74353 GitHub repo that fixes Closed-Display Mode power transitions; upstream has no releases, so the DMG URL is pinned to a commit SHA and the version is derived from that commit's date)

## Updating packages

### RAR (manual version bump required)

```bash
# Local
scripts/update-rar.sh 7.21

# GitHub Actions (workflow_dispatch)
# Workflow: update-rar — provide version input (e.g. 7.21)
```

The script downloads both ARM and Intel tarballs, computes their SHA256s, and patches `Formula/rar.rb` in place.

### OpenIn Helper (can auto-detect latest)

```bash
# Local — latest stable from appcast
scripts/update-openin-helper.sh

# Local — specific version
scripts/update-openin-helper.sh 4.3.5

# GitHub Actions (workflow_dispatch)
# Workflow: update-openin-helper — version input optional
```

The script parses `https://loshadki.app/openin-helper4/releases/appcast.xml` (Sparkle format), skipping items with a non-empty `sparkle:channel` (pre-releases), then patches `Casks/openin-helper.rb`.

### truenas-mcp (auto-detects latest GitHub release)

```bash
# Local — latest GitHub release
scripts/update-truenas-mcp.sh

# Local — specific version tag
scripts/update-truenas-mcp.sh v0.0.5

# GitHub Actions (workflow_dispatch or weekly Monday cron)
# Workflow: update-truenas-mcp — version input optional
```

### herdr-mx (auto-detects latest GitHub release)

```bash
# Local — latest GitHub release
scripts/update-herdr-mx.sh

# Local — specific release tag
scripts/update-herdr-mx.sh v0.7.1-mx.1

# GitHub Actions (workflow_dispatch or weekly Monday cron)
# Workflow: update-herdr-mx — version input optional
```

The script downloads all four prebuilt binaries (macOS/Linux × ARM/Intel), **verifies each one's detached minisign signature against the fork's pinned public key before trusting it** (fails closed on a missing/invalid signature), computes their SHA256s, and regenerates the `on_macos`/`on_linux` blocks in `Formula/herdr-mx.rb`. Requires `minisign` in `PATH` (`brew install minisign`). Release tags carry an `-mx.N` suffix (e.g. `v0.7.1-mx.1`).

### amphetamine-power-protect (auto-detects latest DMG commit)

```bash
# Local — latest commit touching the DMG
scripts/update-amphetamine-power-protect.sh

# Local — pin a specific commit SHA
scripts/update-amphetamine-power-protect.sh 895cfd55042cef4ccbe15741d022456ddd9bb2e3

# GitHub Actions (workflow_dispatch or weekly Monday cron)
# Workflow: update-amphetamine-power-protect — commit input optional
```

Upstream (`x74353/Amphetamine-Power-Protect`) has no releases or tags — it just replaces the DMG on `main`. The script queries the GitHub API for the latest commit touching `DMG/Power Protect for Amphetamine.dmg`, pins the raw download URL to that **immutable commit SHA** (so the SHA256 is stable), derives the cask `version` from that commit's date (`YYYY.MM.DD`), computes the DMG SHA256, and patches `Casks/amphetamine-power-protect.rb`. Set `GITHUB_TOKEN` to lift the API rate limit.

## Validating changes

```bash
# Lint/style check
brew style --formula drod3763/tap/rar
brew style --formula drod3763/tap/truenas-mcp
brew style --formula drod3763/tap/herdr-mx
brew style --cask drod3763/tap/openin-helper
brew style --cask drod3763/tap/amphetamine-power-protect

# Audit
brew audit --strict drod3763/tap/rar
brew audit --strict drod3763/tap/truenas-mcp
brew audit --strict drod3763/tap/herdr-mx
brew audit --cask --strict drod3763/tap/openin-helper
brew audit --cask --strict drod3763/tap/amphetamine-power-protect
```

CI (`tests.yml`) runs `brew test-bot` across Ubuntu, macOS Intel, and macOS ARM on every push/PR.

## Commit conventions

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>
```

Types used in this repo:

| Type | When |
|------|------|
| `feat` | New formula, cask, or updater script |
| `fix` | Bug fix in formula, cask, or script |
| `chore` | Repo setup, CI config, tooling changes |
| `build` | Version/SHA bumps from updater scripts |

Examples:
```
feat: add truenas-mcp formula with automated updater
fix: resolve shfmt and shellcheck issues in update-truenas-mcp.sh
build(rar): bump to 7.21
chore: init drod3763/tap homebrew tap
```

## Key conventions

- Update scripts patch Ruby source files via inline `ruby -e` — no gems needed, just `curl` + `shasum`/`sha256sum`.
- RAR URL pattern: `rarmacos-arm-<compact_version>.tar.gz` where compact strips dots (e.g. `7.20` → `720`).
- OpenIn Helper URL pattern: `OpenIn%20Helper%20<version>.zip` (space URL-encoded).
- Power Protect has no upstream releases: the cask URL is pinned to a commit SHA (`raw.githubusercontent.com/x74353/Amphetamine-Power-Protect/<sha>/DMG/...`) and the version is that commit's date. The DMG holds a `.pkg`; the cask uses `pkg` + `uninstall pkgutil:` (macOS Installer handles the Touch ID/sudoers auth — no hand-rolled root writes).
- PR merge goes through the `publish.yml` (`brew pr-pull`) workflow triggered by adding a `pr-pull` label.
