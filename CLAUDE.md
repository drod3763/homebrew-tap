# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Homebrew third-party tap (`drod3763/tap`) hosting two packages:

- **`Formula/rar.rb`** — Formula for the RAR CLI (downloads prebuilt binaries from rarlab.com; dual-arch: ARM + Intel)
- **`Formula/truenas-mcp.rb`** — Formula for TrueNAS MCP server (builds from source via `go build`; requires Go)
- **`Casks/openin-helper.rb`** — Cask for OpenIn Helper macOS app (downloaded from loshadki.app appcast)

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

## Validating changes

```bash
# Lint/style check
brew style --formula drod3763/tap/rar
brew style --formula drod3763/tap/truenas-mcp
brew style --cask drod3763/tap/openin-helper

# Audit
brew audit --strict drod3763/tap/rar
brew audit --strict drod3763/tap/truenas-mcp
brew audit --cask --strict drod3763/tap/openin-helper
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
- PR merge goes through the `publish.yml` (`brew pr-pull`) workflow triggered by adding a `pr-pull` label.
