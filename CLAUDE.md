# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Homebrew third-party tap (`drod3763/tap`) hosting these packages:

- **`Formula/rar.rb`** — Formula for the RAR CLI (downloads prebuilt binaries from rarlab.com; dual-arch: ARM + Intel)
- **`Formula/truenas-mcp.rb`** — Formula for TrueNAS MCP server (builds from source via `go build`; requires Go)
- **`Formula/humble-cli.rb`** — Formula for humble-cli, a CLI for downloading Humble Bundle purchases (builds from source via `go build`; requires Go; injects the version via `-X main.version` and installs bash/zsh/fish completions)
- **`Formula/herdr-mx.rb`** — Formula for the herdr-mx fork (downloads prebuilt, minisign-signed binaries from GitHub Releases; dual-OS macOS + Linux, dual-arch ARM + Intel; self-update disabled by design, so updates ship through this tap)
- **`Formula/git-delta-fork.rb`** — Formula for the drod3763 delta fork (HEAD-only; builds from source via `cargo`)
- **`Casks/openin-helper.rb`** — Cask for OpenIn Helper macOS app (downloaded from loshadki.app appcast)
- **`Casks/herdr-server.rb`** — Cask for Herdr Server.app (a bundled, resident parent for `herdr server` so macOS can grant it Local Network/TCC consent, herdrdev/herdr#808; zip from `drod3763/herdr-server-app` GitHub Releases; the Local Network grant is bound to each build's ad-hoc signature, so an upgrade replaces the granted bundle and the launcher must be re-granted after it restarts)
- **`Casks/amphetamine-power-protect.rb`** — Cask for Power Protect for Amphetamine (runs a `.pkg` from a DMG in the x74353 GitHub repo that fixes Closed-Display Mode power transitions; upstream has no releases, so the DMG URL is pinned to a commit SHA and the version is derived from that commit's timestamp)
- **`Casks/pocket-sync.rb`** — Cask for Pocket Sync, a desktop app for managing an Analogue Pocket (universal DMG from `neil-morrison44/pocket-sync` GitHub Releases; signed + notarized; the app self-updates via Tauri, so the cask sets `auto_updates true`)
- **`Casks/rex.rb`** — Cask for Superlogical's Rex beta (`Rex Beta.app`; universal DMG from the public snapshot channel on `blob.superlogical.com`; Developer ID signed + notarized; the app self-updates via Sparkle, so the cask sets `auto_updates true`)

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

### humble-cli (auto-detects latest GitHub release)

```bash
# Local — latest GitHub release
scripts/update-humble-cli.sh

# Local — specific version tag
scripts/update-humble-cli.sh v0.23.2

# GitHub Actions (workflow_dispatch or weekly Monday cron)
# Workflow: update-humble-cli — version input optional
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

### herdr-server (auto-detects latest GitHub release)

```bash
# Local — latest release
scripts/update-herdr-server.sh

# Local — specific tag
scripts/update-herdr-server.sh v0.1.0

# GitHub Actions (workflow_dispatch)
# Workflow: update-herdr-server — tag input optional
```

The script downloads `Herdr-Server-<version>.zip` and its published `.sha256` from `drod3763/herdr-server-app` releases, refuses to pin unless the two agree, and patches `Casks/herdr-server.rb`. Each release is built once in that repo's CI because the Local Network grant binds to the build's ad-hoc signature; never rebuild the bundle in place on a granted machine.

### amphetamine-power-protect (auto-detects latest DMG commit)

```bash
# Local — latest commit touching the DMG
scripts/update-amphetamine-power-protect.sh

# Local — pin a specific commit SHA
scripts/update-amphetamine-power-protect.sh 895cfd55042cef4ccbe15741d022456ddd9bb2e3

# GitHub Actions (workflow_dispatch or weekly Monday cron)
# Workflow: update-amphetamine-power-protect — commit input optional
```

Upstream (`x74353/Amphetamine-Power-Protect`) has no releases or tags — it just replaces the DMG on `main`. The script queries the GitHub API for the latest commit touching `DMG/Power Protect for Amphetamine.dmg`, pins the raw download URL to that **immutable commit SHA** (so the SHA256 is stable), derives the cask `version` from that commit's timestamp (`YYYY.MM.DD.HHMMSS`, monotonic even for same-day DMG changes), computes the DMG SHA256, and patches `Casks/amphetamine-power-protect.rb`. Set `GITHUB_TOKEN` to lift the API rate limit.

Because the cask installs a root-running, sudoers-writing `.pkg`, the updater **verifies the DMG contract before writing** — it mounts the DMG and asserts it ships `Install Power Protect.pkg`, notarized and signed by the fork author's Developer ID (`U5SR49N3PT`), with receipt `com.if.pkg.AmphetaminePowerProtect`. This needs macOS (`hdiutil`/`pkgutil`); the update workflow runs on a macOS runner for this reason. Off macOS the script **fails closed** unless `AMPHETAMINE_PP_ALLOW_UNVERIFIED=1` is set. A manually-passed commit SHA is rejected unless that commit actually modified the DMG.

### pocket-sync (auto-detects latest GitHub release)

```bash
# Local — latest GitHub release
scripts/update-pocket-sync.sh

# Local — specific release tag
scripts/update-pocket-sync.sh v7.1.1

# GitHub Actions (workflow_dispatch or weekly Monday cron)
# Workflow: update-pocket-sync — version input optional
```

Upstream publishes no `.sha256` sidecar, so the script reads the asset's `digest` from the GitHub releases API and refuses to pin unless it matches the SHA256 of the downloaded `Pocket.Sync_<version>_universal.dmg` (fails closed if the asset or digest is missing), then patches `Casks/pocket-sync.rb`.

### rex (manual bump)

No updater script. Snapshot builds ship roughly hourly and the app updates itself through Sparkle, so the pinned build only matters for fresh installs. Old snapshot DMGs stay hosted, so the pinned URL keeps working. To bump:

```bash
brew bump --cask --open-pr --no-fork drod3763/tap/rex
```

`livecheck` reads the Sparkle appcast at `https://blob.superlogical.com/public/rex-app/snapshot/appcast.xml`; the version is `<short version>,<build>` (e.g. `0.1.0,1632`).

## Validating changes

```bash
# Lint/style check
brew style --formula drod3763/tap/rar
brew style --formula drod3763/tap/truenas-mcp
brew style --formula drod3763/tap/humble-cli
brew style --formula drod3763/tap/herdr-mx
brew style --cask drod3763/tap/openin-helper
brew style --cask drod3763/tap/amphetamine-power-protect
brew style --cask drod3763/tap/pocket-sync
brew style --cask drod3763/tap/rex

# Audit
brew audit --strict drod3763/tap/rar
brew audit --strict drod3763/tap/truenas-mcp
brew audit --strict drod3763/tap/humble-cli
brew audit --strict drod3763/tap/herdr-mx
brew audit --cask --strict drod3763/tap/openin-helper
brew audit --cask --strict drod3763/tap/amphetamine-power-protect
brew audit --cask --strict drod3763/tap/pocket-sync
brew audit --cask --strict drod3763/tap/rex
```

CI (`tests.yml`) runs `brew test-bot` across Ubuntu, macOS Intel, and macOS ARM on every push/PR.

## Commit conventions

Use [Conventional Commits](https://www.conventionalcommits.org/) for hand-written changes:

```
<type>[optional scope]: <description>
```

Types used in this repo:

| Type | When |
|------|------|
| `feat` | New formula, cask, or updater script |
| `fix` | Bug fix in formula, cask, or script |
| `chore` | Repo setup, CI config, tooling changes |

Examples:
```
feat: add truenas-mcp formula with automated updater
fix: resolve shfmt and shellcheck issues in update-truenas-mcp.sh
chore: init drod3763/tap homebrew tap
```

Version bumps (from updater scripts or workflows) use Homebrew's own format instead, `<name> <version>` with the bare version (no `v` prefix), e.g. `rar 7.21` or `herdr-mx 0.7.3-mx.1`. This matches homebrew-core's [required format](https://docs.brew.sh/Formula-Cookbook#commit) and what `brew bump-formula-pr` generates.

## Key conventions

- Update scripts patch Ruby source files via inline `ruby -e` — no gems needed, just `curl` + `shasum`/`sha256sum`.
- RAR URL pattern: `rarmacos-arm-<compact_version>.tar.gz` where compact strips dots (e.g. `7.20` → `720`).
- OpenIn Helper URL pattern: `OpenIn%20Helper%20<version>.zip` (space URL-encoded).
- Power Protect has no upstream releases: the cask URL is pinned to a commit SHA (`raw.githubusercontent.com/x74353/Amphetamine-Power-Protect/<sha>/DMG/...`) and the version is that commit's timestamp (`YYYY.MM.DD.HHMMSS`). The DMG holds a `.pkg`; the cask uses `pkg` + `uninstall pkgutil:` (macOS Installer handles the Touch ID/sudoers auth — no hand-rolled root writes).
- Every updater workflow is split into read-only jobs (`contents: read`, checkout with `persist-credentials: false`) that run the updater, style/audit and any install/test, and a write job that only downloads the validated file as an artifact and opens the PR (`add-paths:` scoped to that file). The write job never sets up Homebrew or runs upstream code, and it re-validates the version string before using it in the branch/title. Keep new updaters in this shape; bind `workflow_dispatch` inputs through `env:`, never `${{ inputs.* }}` in a `run:` body.
- The write jobs open PRs with the `TAP_PR_TOKEN` secret (fine-grained PAT scoped to this repo: Contents + Pull requests read/write). PRs opened with the default `GITHUB_TOKEN` have their `tests.yml` run held at `action_required` until manually approved; the PAT avoids that. Never give the PAT to a job that also downloads or runs upstream content. If the secret is missing, the workflows fall back to `GITHUB_TOKEN` (PRs still open, but the hold returns). The PAT is set to no expiration, but GitHub deletes PATs unused for a year; an invalid PAT fails the "Create pull request" step (it does not fall back), so regenerate it and re-run `gh secret set TAP_PR_TOKEN`.
- `main` is protected by the "Protect main" ruleset with no bypass actors: every change lands through a PR, and the four `test-bot` checks must pass. Merge PRs with a squash merge. No bottles are published, and the `publish.yml` (`brew pr-pull`) label flow can't push to `main`, so don't use it.
