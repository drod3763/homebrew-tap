#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
formula_path="${repo_root}/Formula/herdr-mx.rb"

if [[ $# -gt 1 ]]
then
  printf 'Usage: %s [tag]\n' "$0" >&2
  printf 'Examples:\n' >&2
  printf '  %s                # use latest GitHub release\n' "$0" >&2
  printf '  %s v0.7.1-mx.1    # pin specific release tag\n' "$0" >&2
  exit 1
fi

detect_latest() {
  # shellcheck disable=SC2016
  curl -fsSL "https://api.github.com/repos/drod3763/herdr-mx/releases/latest" |
    ruby -rjson -e 'puts JSON.parse($stdin.read).fetch("tag_name")'
}

if [[ $# -eq 1 ]]
then
  tag="$1"
else
  printf 'Detecting latest release...\n'
  tag="$(detect_latest)"
fi

if [[ ! "${tag}" =~ ^v[0-9]+(\.[0-9]+)*-mx\.[0-9]+$ ]]
then
  printf 'Tag must look like v0.7.1-mx.1\n' >&2
  exit 1
fi

version="${tag#v}"
base="https://github.com/drod3763/herdr-mx/releases/download/${tag}"

sha_for_url() {
  local url="$1"
  if command -v shasum >/dev/null 2>&1
  then
    curl -fsSL "${url}" | shasum -a 256 | cut -d' ' -f1
    return
  fi

  if command -v sha256sum >/dev/null 2>&1
  then
    curl -fsSL "${url}" | sha256sum | cut -d' ' -f1
    return
  fi

  printf 'Need shasum or sha256sum in PATH\n' >&2
  exit 1
}

printf 'Calculating macOS arm64 checksum...\n'
macos_arm_sha="$(sha_for_url "${base}/herdr-macos-aarch64")"
printf 'Calculating macOS x86_64 checksum...\n'
macos_intel_sha="$(sha_for_url "${base}/herdr-macos-x86_64")"
printf 'Calculating Linux arm64 checksum...\n'
linux_arm_sha="$(sha_for_url "${base}/herdr-linux-aarch64")"
printf 'Calculating Linux x86_64 checksum...\n'
linux_intel_sha="$(sha_for_url "${base}/herdr-linux-x86_64")"

FORMULA_PATH="${formula_path}" VERSION="${version}" TAG="${tag}" \
  MACOS_ARM_SHA="${macos_arm_sha}" MACOS_INTEL_SHA="${macos_intel_sha}" \
  LINUX_ARM_SHA="${linux_arm_sha}" LINUX_INTEL_SHA="${linux_intel_sha}" ruby -e '
path = ENV.fetch("FORMULA_PATH")
version = ENV.fetch("VERSION")
tag = ENV.fetch("TAG")
macos_arm_sha = ENV.fetch("MACOS_ARM_SHA")
macos_intel_sha = ENV.fetch("MACOS_INTEL_SHA")
linux_arm_sha = ENV.fetch("LINUX_ARM_SHA")
linux_intel_sha = ENV.fetch("LINUX_INTEL_SHA")

base = "https://github.com/drod3763/herdr-mx/releases/download/#{tag}"

content = File.read(path)
updated = content.sub(/version "[^"]+"/, %(version "#{version}"))

macos_block = "  on_macos do\n" \
              "    if Hardware::CPU.arm?\n" \
              "      url \"#{base}/herdr-macos-aarch64\"\n" \
              "      sha256 \"#{macos_arm_sha}\"\n" \
              "    else\n" \
              "      url \"#{base}/herdr-macos-x86_64\"\n" \
              "      sha256 \"#{macos_intel_sha}\"\n" \
              "    end\n" \
              "  end\n"

linux_block = "  on_linux do\n" \
              "    if Hardware::CPU.arm?\n" \
              "      url \"#{base}/herdr-linux-aarch64\"\n" \
              "      sha256 \"#{linux_arm_sha}\"\n" \
              "    else\n" \
              "      url \"#{base}/herdr-linux-x86_64\"\n" \
              "      sha256 \"#{linux_intel_sha}\"\n" \
              "    end\n" \
              "  end\n"

updated.sub!(/  on_macos do\n.*?\n  end\n/m, macos_block)
updated.sub!(/  on_linux do\n.*?\n  end\n/m, linux_block)

[macos_arm_sha, macos_intel_sha, linux_arm_sha, linux_intel_sha].each do |sha|
  raise "Failed to update #{path}: missing #{sha}" unless updated.include?(sha)
end
raise "Failed to update #{path}: version" unless updated.include?(%(version "#{version}"))

File.write(path, updated)
'

printf 'Updated %s to %s\n' "${formula_path}" "${tag}"
printf 'macOS arm64:   %s\n' "${macos_arm_sha}"
printf 'macOS x86_64:  %s\n' "${macos_intel_sha}"
printf 'Linux arm64:   %s\n' "${linux_arm_sha}"
printf 'Linux x86_64:  %s\n' "${linux_intel_sha}"
