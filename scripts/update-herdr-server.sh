#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cask_path="${repo_root}/Casks/herdr-server.rb"

if [[ $# -gt 1 ]]
then
  printf 'Usage: %s [tag]\n' "$0" >&2
  printf 'Examples:\n' >&2
  printf '  %s           # use latest GitHub release\n' "$0" >&2
  printf '  %s v0.1.0    # pin specific release tag\n' "$0" >&2
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

detect_latest() {
  gh_api_get "https://api.github.com/repos/drod3763/herdr-server-app/releases/latest" |
    ruby -rjson -e 'puts JSON.parse(STDIN.read).fetch("tag_name")'
}

if [[ $# -eq 1 ]]
then
  tag="$1"
else
  printf 'Detecting latest release...\n'
  tag="$(detect_latest)"
fi

if [[ ! "${tag}" =~ ^v[0-9]+(\.[0-9]+)+$ ]]
then
  printf 'Tag must look like v0.1.0\n' >&2
  exit 1
fi

version="${tag#v}"
base="https://github.com/drod3763/herdr-server-app/releases/download/${tag}"
asset="Herdr-Server-${version}.zip"

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

workdir="$(mktemp -d "${TMPDIR:-/tmp}/herdr-server.XXXXXX")"
trap 'rm -rf "${workdir}"' EXIT

# The release ships its own .sha256 next to the zip; require the two to agree before
# pinning, so a partial download or a swapped asset cannot land as a "valid" checksum.
printf 'Downloading + hashing %s...\n' "${asset}"
curl -fsSL -o "${workdir}/${asset}" "${base}/${asset}"
curl -fsSL -o "${workdir}/${asset}.sha256" "${base}/${asset}.sha256"
sha="$(sha256_of "${workdir}/${asset}")"
published="$(cut -d' ' -f1 "${workdir}/${asset}.sha256")"
if [[ "${sha}" != "${published}" ]]
then
  printf 'Checksum mismatch: computed %s, release says %s\n' "${sha}" "${published}" >&2
  exit 1
fi

CASK_PATH="${cask_path}" VERSION="${version}" SHA="${sha}" ruby -e '
path = ENV.fetch("CASK_PATH")
version = ENV.fetch("VERSION")
sha = ENV.fetch("SHA")

content = File.read(path)
raise "Failed to update #{path}: version line not found" unless content =~ /version "[^"]+"/
raise "Failed to update #{path}: sha256 line not found" unless content =~ /sha256 "[^"]+"/

updated = content.sub(/version "[^"]+"/, %(version "#{version}"))
updated = updated.sub(/sha256 "[^"]+"/, %(sha256 "#{sha}"))

raise "Failed to update #{path}: version" unless updated.include?(%(version "#{version}"))
raise "Failed to update #{path}: sha256" unless updated.include?(%(sha256 "#{sha}"))

File.write(path, updated)
'

printf 'Updated %s to %s (%s)\n' "${cask_path}" "${version}" "${sha}"
