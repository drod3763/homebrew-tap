#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
formula_path="${repo_root}/Formula/truenas-mcp.rb"

if [[ $# -gt 1 ]]; then
  printf 'Usage: %s [version]\n' "$0" >&2
  printf 'Examples:\n' >&2
  printf '  %s          # use latest GitHub release\n' "$0" >&2
  printf '  %s v0.0.5   # pin specific version tag\n' "$0" >&2
  exit 1
fi

detect_latest() {
  curl -fsSL "https://api.github.com/repos/truenas/truenas-mcp/releases/latest" \
    | ruby -rjson -e 'puts JSON.parse($stdin.read).fetch("tag_name")'
}

if [[ $# -eq 1 ]]; then
  version="$1"
else
  printf 'Detecting latest release...\n'
  version="$(detect_latest)"
fi

if [[ ! "${version}" =~ ^v[0-9]+(\.[0-9]+)*$ ]]; then
  printf 'Version must look like v0.0.5\n' >&2
  exit 1
fi

url="https://github.com/truenas/truenas-mcp/archive/refs/tags/${version}.tar.gz"

printf 'Calculating SHA256 for %s...\n' "${url}"
if command -v shasum >/dev/null 2>&1; then
  sha256="$(curl -fsSL "${url}" | shasum -a 256 | cut -d' ' -f1)"
elif command -v sha256sum >/dev/null 2>&1; then
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
updated = content.gsub(%r{url "https://github\.com/truenas/truenas-mcp/archive/refs/tags/[^"]+"}, %(url "#{url}"))
updated = updated.gsub(/sha256 "[0-9a-f]{64}"/, %(sha256 "#{sha256}"))

unless updated.include?(%(url "#{url}")) && updated.include?(%(sha256 "#{sha256}"))
  raise "Failed to update #{path}"
end

File.write(path, updated)
'

printf 'Updated %s to %s\n' "${formula_path}" "${version}"
printf 'SHA256: %s\n' "${sha256}"
