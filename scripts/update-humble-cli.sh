#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
formula_path="${repo_root}/Formula/humble-cli.rb"

if [[ $# -gt 1 ]]
then
  printf 'Usage: %s [version]\n' "$0" >&2
  printf 'Examples:\n' >&2
  printf '  %s          # use latest GitHub release\n' "$0" >&2
  printf '  %s v0.23.2   # pin specific version tag\n' "$0" >&2
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
  # shellcheck disable=SC2016
  gh_api_get "https://api.github.com/repos/smbl64/humble-cli/releases/latest" |
    ruby -rjson -e 'puts JSON.parse($stdin.read).fetch("tag_name")'
}

if [[ $# -eq 1 ]]
then
  version="$1"
else
  printf 'Detecting latest release...\n'
  version="$(detect_latest)"
fi

if [[ ! "${version}" =~ ^v[0-9]+(\.[0-9]+)*$ ]]
then
  printf 'Version must look like v0.23.2\n' >&2
  exit 1
fi

url="https://github.com/smbl64/humble-cli/archive/refs/tags/${version}.tar.gz"

printf 'Calculating SHA256 for %s...\n' "${url}"
if command -v shasum >/dev/null 2>&1
then
  sha256="$(curl -fsSL "${url}" | shasum -a 256 | cut -d' ' -f1)"
elif command -v sha256sum >/dev/null 2>&1
then
  sha256="$(curl -fsSL "${url}" | sha256sum | cut -d' ' -f1)"
else
  printf 'Need shasum or sha256sum in PATH\n' >&2
  exit 1
fi

FORMULA_PATH="${formula_path}" VERSION="${version}" URL="${url}" SHA256="${sha256}" ruby -e '
path = ENV.fetch("FORMULA_PATH")
version = ENV.fetch("VERSION")
url = ENV.fetch("URL")
sha256 = ENV.fetch("SHA256")

content = File.read(path)
updated = content.gsub(%r{url "https://github\.com/smbl64/humble-cli/archive/refs/tags/[^"]+"}, %(url "#{url}"))
updated = updated.gsub(/sha256 "[0-9a-f]{64}"/, %(sha256 "#{sha256}"))

unless updated.include?(%(url "#{url}")) && updated.include?(%(sha256 "#{sha256}"))
  raise "Failed to update #{path}"
end

File.write(path, updated)
'

printf 'Updated %s to %s\n' "${formula_path}" "${version}"
printf 'SHA256: %s\n' "${sha256}"
