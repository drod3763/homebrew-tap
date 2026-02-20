#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]
then
  printf 'Usage: %s <version>\n' "$0" >&2
  printf 'Example: %s 7.21\n' "$0" >&2
  exit 1
fi

version="$1"
if [[ ! "${version}" =~ ^[0-9]+(\.[0-9]+)*$ ]]
then
  printf 'Version must look like 7.20\n' >&2
  exit 1
fi

compact_version="${version//./}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
formula_path="${repo_root}/Formula/rar.rb"

arm_url="https://www.win-rar.com/fileadmin/winrar-versions/rarmacos-arm-${compact_version}.tar.gz"
intel_url="https://www.win-rar.com/fileadmin/winrar-versions/rarmacos-x64-${compact_version}.tar.gz"

sha_for_url() {
  local url="$1"
  if command -v shasum >/dev/null 2>&1
  then
    curl -fL "${url}" | shasum -a 256 | cut -d' ' -f1
    return
  fi

  if command -v sha256sum >/dev/null 2>&1
  then
    curl -fL "${url}" | sha256sum | cut -d' ' -f1
    return
  fi

  printf 'Need shasum or sha256sum in PATH\n' >&2
  exit 1
}

printf 'Calculating ARM checksum...\n'
arm_sha="$(sha_for_url "${arm_url}")"

printf 'Calculating Intel checksum...\n'
intel_sha="$(sha_for_url "${intel_url}")"

FORMULA_PATH="${formula_path}" VERSION="${version}" COMPACT_VERSION="${compact_version}" ARM_SHA="${arm_sha}" INTEL_SHA="${intel_sha}" ruby -e '
path = ENV.fetch("FORMULA_PATH")
version = ENV.fetch("VERSION")
compact = ENV.fetch("COMPACT_VERSION")
arm_sha = ENV.fetch("ARM_SHA")
intel_sha = ENV.fetch("INTEL_SHA")

content = File.read(path)
updated = content.gsub(/version "\d+(?:\.\d+)*"/, %(version "#{version}"))

arch_block = "  if Hardware::CPU.arm?\n" \
             "    url \"https://www.win-rar.com/fileadmin/winrar-versions/rarmacos-arm-#{compact}.tar.gz\"\n" \
             "    sha256 \"#{arm_sha}\"\n" \
             "  else\n" \
             "    url \"https://www.win-rar.com/fileadmin/winrar-versions/rarmacos-x64-#{compact}.tar.gz\"\n" \
             "    sha256 \"#{intel_sha}\"\n" \
             "  end\n\n"

updated.sub!(%r{  if Hardware::CPU\.arm\?\n.*?\n  end\n\n}m, arch_block)

unless updated.include?(arm_sha) && updated.include?(intel_sha)
  raise "Failed to update #{path}"
end

File.write(path, updated)
'

printf 'Updated %s to version %s\n' "${formula_path}" "${version}"
printf 'ARM SHA256:   %s\n' "${arm_sha}"
printf 'Intel SHA256: %s\n' "${intel_sha}"
