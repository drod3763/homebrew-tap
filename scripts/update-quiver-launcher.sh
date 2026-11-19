#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cask_path="${repo_root}/Casks/quiver-launcher.rb"
repo="tgeorgiadis/quiver-launcher"

if [[ $# -gt 1 ]]
then
  printf 'Usage: %s [tag]\n' "$0" >&2
  printf 'Examples:\n' >&2
  printf '  %s           # use latest stable GitHub release\n' "$0" >&2
  printf '  %s v3.5.1    # pin specific release tag\n' "$0" >&2
  exit 1
fi

# Fetch a GitHub API URL, adding the auth header only when a token is present (a token lifts
# the unauthenticated rate limit shared by every job on a runner's public IP).
gh_api_get() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]
  then
    curl -fsSL -H "Authorization: Bearer ${GITHUB_TOKEN}" "$1"
  else
    curl -fsSL "$1"
  fi
}

if [[ $# -eq 1 ]]
then
  tag="$1"
else
  printf 'Detecting latest stable release...\n'
  tag="$(
    gh_api_get "https://api.github.com/repos/${repo}/releases/latest" |
      ruby -rjson -e 'puts JSON.parse(STDIN.read).fetch("tag_name")'
  )"
fi

if [[ ! "${tag}" =~ ^v[0-9]+(\.[0-9]+)+$ ]]
then
  printf 'Tag must look like v3.5.1 (stable only; prereleases go to quiver-launcher@beta)\n' >&2
  exit 1
fi

version="${tag#v}"
base="https://github.com/${repo}/releases/download/${tag}"

if command -v shasum >/dev/null 2>&1
then
  sha256_of() { shasum -a 256 "$1" | cut -d' ' -f1; }
elif command -v sha256sum >/dev/null 2>&1
then
  sha256_of() { sha256sum "$1" | cut -d' ' -f1; }
else
  printf 'Need shasum or sha256sum in PATH\n' >&2
  exit 1
fi

workdir="$(mktemp -d "${TMPDIR:-/tmp}/quiver-launcher.XXXXXX")"
trap 'rm -rf "${workdir}"' EXIT

release_json="${workdir}/release.json"
gh_api_get "https://api.github.com/repos/${repo}/releases/tags/${tag}" >"${release_json}"

# Upstream ships no .sha256 sidecar, but GitHub records a digest for every release asset;
# require it to agree with the download before pinning, so a partial download or a swapped
# asset cannot land as a "valid" checksum. Fails closed if an asset or digest is missing,
# which is also what happens if a stable release drops the per-arch Portable.zip layout
# (the 4.x line ships a universal DMG): the cask then needs a manual migration.
verified_sha() {
  local asset="$1" published sha
  printf 'Looking up GitHub digest for %s...\n' "${asset}" >&2
  published="$(
    ASSET="${asset}" ruby -rjson -e '
      asset = JSON.parse(File.read(ARGV[0])).fetch("assets").find { |a| a["name"] == ENV.fetch("ASSET") }
      abort "Release has no asset #{ENV.fetch("ASSET")} (did the release layout change?)" unless asset
      digest = asset["digest"].to_s
      abort "Asset has no sha256 digest" unless digest.start_with?("sha256:")
      puts digest.delete_prefix("sha256:")
    ' "${release_json}"
  )"
  printf 'Downloading + hashing %s...\n' "${asset}" >&2
  curl -fsSL -o "${workdir}/${asset}" "${base}/${asset}"
  sha="$(sha256_of "${workdir}/${asset}")"
  if [[ "${sha}" != "${published}" ]]
  then
    printf 'Checksum mismatch for %s: computed %s, release says %s\n' "${asset}" "${sha}" "${published}" >&2
    exit 1
  fi
  printf '%s\n' "${sha}"
}

sha_arm="$(verified_sha "QuiverLauncher-osx-arm64-Portable.zip")"
sha_intel="$(verified_sha "QuiverLauncher-osx-x64-Portable.zip")"

CASK_PATH="${cask_path}" VERSION="${version}" SHA_ARM="${sha_arm}" SHA_INTEL="${sha_intel}" ruby -e '
path = ENV.fetch("CASK_PATH")
version = ENV.fetch("VERSION")
sha_arm = ENV.fetch("SHA_ARM")
sha_intel = ENV.fetch("SHA_INTEL")

content = File.read(path)
raise "Failed to update #{path}: version line not found" unless content =~ /version "[^"]+"/
raise "Failed to update #{path}: arm sha256 not found" unless content =~ /sha256 arm:\s+"[^"]+"/
raise "Failed to update #{path}: intel sha256 not found" unless content =~ /intel: "[0-9a-f]{64}"/

updated = content.sub(/version "[^"]+"/, %(version "#{version}"))
updated = updated.sub(/(sha256 arm:\s+)"[^"]+"/) { %(#{Regexp.last_match(1)}"#{sha_arm}") }
updated = updated.sub(/intel: "[0-9a-f]{64}"/, %(intel: "#{sha_intel}"))

raise "Failed to update #{path}: version" unless updated.include?(%(version "#{version}"))
raise "Failed to update #{path}: arm sha256" unless updated.include?(%("#{sha_arm}"))
raise "Failed to update #{path}: intel sha256" unless updated.include?(%(intel: "#{sha_intel}"))

File.write(path, updated)
'

printf 'Updated %s to %s (arm %s, intel %s)\n' "${cask_path}" "${version}" "${sha_arm}" "${sha_intel}"
