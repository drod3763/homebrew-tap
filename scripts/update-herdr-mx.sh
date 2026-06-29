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

# Pinned minisign (ed25519) public key herdr-mx signs its release artifacts with —
# the base64 key line from ACCEPTED_PUBKEYS in the fork's src/signing.rs. Verifying the
# detached .minisig before trusting any bytes means a compromised or swapped release
# asset cannot be pinned into the formula with a "valid" Homebrew checksum.
readonly MINISIGN_PUBKEY="RWQupm2xx/vDQ2YjRHgy/84xAkdgzIgwIN/4CyOy5n1rQRQnHW34r3D2"

if ! command -v minisign >/dev/null 2>&1
then
  printf 'Need minisign in PATH to verify release signatures (brew install minisign)\n' >&2
  exit 1
fi

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

workdir="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '${workdir}'" EXIT

# Download an asset and its detached signature, verify the signature against the pinned
# key (fail closed on a missing or invalid signature), then print the SHA256.
sha_for_asset() {
  local name="$1"
  local file="${workdir}/${name}"
  curl -fsSL -o "${file}" "${base}/${name}"
  curl -fsSL -o "${file}.minisig" "${base}/${name}.minisig"
  if ! minisign -V -P "${MINISIGN_PUBKEY}" -m "${file}" -x "${file}.minisig" >/dev/null 2>&1
  then
    printf 'minisign verification FAILED for %s — refusing to pin unverified asset\n' "${name}" >&2
    exit 1
  fi
  sha256_of "${file}"
}

printf 'Verifying + hashing macOS arm64...\n'
macos_arm_sha="$(sha_for_asset "herdr-macos-aarch64")"
printf 'Verifying + hashing macOS x86_64...\n'
macos_intel_sha="$(sha_for_asset "herdr-macos-x86_64")"
printf 'Verifying + hashing Linux arm64...\n'
linux_arm_sha="$(sha_for_asset "herdr-linux-aarch64")"
printf 'Verifying + hashing Linux x86_64...\n'
linux_intel_sha="$(sha_for_asset "herdr-linux-x86_64")"

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
