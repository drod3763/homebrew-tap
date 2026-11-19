#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cask_path="${repo_root}/Casks/hint-control.rb"
upstream="zacharee/HINTControl"

if [[ $# -gt 1 ]]
then
  printf 'Usage: %s [tag]\n' "$0" >&2
  printf 'Examples:\n' >&2
  printf '  %s           # use latest GitHub release\n' "$0" >&2
  printf '  %s 1.17.3    # pin specific release tag\n' "$0" >&2
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
  gh_api_get "https://api.github.com/repos/${upstream}/releases/latest" |
    ruby -rjson -e 'puts JSON.parse(STDIN.read).fetch("tag_name")'
}

if [[ $# -eq 1 ]]
then
  tag="$1"
else
  printf 'Detecting latest release...\n'
  tag="$(detect_latest)"
fi

# Upstream tags carry no "v" prefix (e.g. 1.17.3).
if [[ ! "${tag}" =~ ^[0-9]+(\.[0-9]+)+$ ]]
then
  printf 'Tag must look like 1.17.3\n' >&2
  exit 1
fi

version="${tag}"

# Refuse to move the cask backwards. If upstream withdraws its newest release, "latest" can
# resolve to an older tag; a scheduled run then leaves the cask untouched (no diff, so no
# PR). An explicitly requested older tag fails unless the rollback is opted into.
current="$(ruby -e 'puts File.read(ARGV[0])[/version "([^"]+)"/, 1]' "${cask_path}")"
if ruby -e 'exit(Gem::Version.new(ARGV[0]) < Gem::Version.new(ARGV[1]) ? 0 : 1)' "${version}" "${current}"
then
  if [[ "${HINT_CONTROL_ALLOW_DOWNGRADE:-}" == "1" ]]
  then
    printf 'Downgrading %s -> %s (HINT_CONTROL_ALLOW_DOWNGRADE=1)\n' "${current}" "${version}" >&2
  elif [[ $# -eq 1 ]]
  then
    printf 'Refusing to downgrade %s -> %s; set HINT_CONTROL_ALLOW_DOWNGRADE=1 to roll back\n' "${current}" "${version}" >&2
    exit 1
  else
    printf 'Latest release %s is older than the cask (%s); leaving the cask unchanged\n' "${version}" "${current}"
    exit 0
  fi
fi

base="https://github.com/${upstream}/releases/download/${tag}"

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

workdir="$(mktemp -d "${TMPDIR:-/tmp}/hint-control.XXXXXX")"
trap 'rm -rf "${workdir}"' EXIT

release_json="${workdir}/release.json"
gh_api_get "https://api.github.com/repos/${upstream}/releases/tags/${tag}" >"${release_json}"

# Upstream ships no .sha256 sidecar, but GitHub records a digest for every release asset;
# require it to agree with the download before pinning, so a partial download or a swapped
# asset cannot land as a "valid" checksum. Fails closed if the asset or digest is missing.
# Callers run this inside $(...), where bash disables errexit, so every step returns
# explicitly on failure instead of relying on `set -e`.
verified_sha() {
  local asset="$1"
  local published sha

  printf 'Looking up GitHub digest for %s...\n' "${asset}" >&2
  published="$(
    ASSET="${asset}" ruby -rjson -e '
      asset = JSON.parse(STDIN.read).fetch("assets").find { |a| a["name"] == ENV.fetch("ASSET") }
      abort "Release has no asset #{ENV.fetch("ASSET")}" unless asset
      digest = asset["digest"].to_s
      abort "Asset has no sha256 digest" unless digest.start_with?("sha256:")
      puts digest.delete_prefix("sha256:")
    ' <"${release_json}"
  )" || return 1

  printf 'Downloading + hashing %s...\n' "${asset}" >&2
  curl -fsSL -o "${workdir}/${asset}" "${base}/${asset}" || return 1
  # A failed hash leaves sha empty; the format check below rejects it.
  sha="$(sha256_of "${workdir}/${asset}")"
  rm -f "${workdir}/${asset}"
  if [[ ! "${published}" =~ ^[0-9a-f]{64}$ || ! "${sha}" =~ ^[0-9a-f]{64}$ ]]
  then
    printf 'Malformed checksum for %s: computed %q, release says %q\n' "${asset}" "${sha}" "${published}" >&2
    return 1
  fi
  if [[ "${sha}" != "${published}" ]]
  then
    printf 'Checksum mismatch for %s: computed %s, release says %s\n' "${asset}" "${sha}" "${published}" >&2
    return 1
  fi
  printf '%s\n' "${sha}"
}

arm_sha="$(verified_sha "hintcontrol-${version}-mac-aarch64.zip")"
intel_sha="$(verified_sha "hintcontrol-${version}-mac-amd64.zip")"

CASK_PATH="${cask_path}" VERSION="${version}" ARM_SHA="${arm_sha}" INTEL_SHA="${intel_sha}" ruby -e '
path = ENV.fetch("CASK_PATH")
version = ENV.fetch("VERSION")
arm_sha = ENV.fetch("ARM_SHA")
intel_sha = ENV.fetch("INTEL_SHA")
[arm_sha, intel_sha].each { |s| raise "Refusing to write malformed sha256 #{s.inspect}" unless s.match?(/\A[0-9a-f]{64}\z/) }

# Read, check and write under one exclusive lock, so a concurrent run cannot slip a newer
# pin in between the version checks and the write. The early downgrade check above only
# avoids needless downloads; this one, against the file as it is now, is authoritative.
# The lock is on the Casks directory, not the cask: the cask is replaced by rename, and a
# lock on its old inode would not stop a waiting run.
lock = File.open(File.dirname(path))
lock.flock(File::LOCK_EX)
content = File.read(path)
raise "Failed to update #{path}: version line not found" unless content =~ /version "[^"]+"/
on_disk = content[/version "([^"]+)"/, 1]
downgrade = Gem::Version.new(version) < Gem::Version.new(on_disk)
abort "Refusing to downgrade #{on_disk} -> #{version}; set HINT_CONTROL_ALLOW_DOWNGRADE=1 to roll back" if downgrade && ENV["HINT_CONTROL_ALLOW_DOWNGRADE"] != "1"
raise "Failed to update #{path}: arm sha256 not found" unless content =~ /arm:\s+"[0-9a-f]{64}"/
raise "Failed to update #{path}: intel sha256 not found" unless content =~ /intel:\s+"[0-9a-f]{64}"/

# Same version, different bytes means upstream replaced assets under an existing tag.
# Never re-pin that silently; accepting it takes a deliberate manual cask edit.
# (Modifier-form Ruby only: the Homebrew shfmt wrapper mangles block if/end inside this string.)
same_version = on_disk == version
pinned = { "arm" => content[/arm:\s+"([0-9a-f]{64})"/, 1], "intel" => content[/intel:\s+"([0-9a-f]{64})"/, 1] }
fresh = { "arm" => arm_sha, "intel" => intel_sha }
changed = same_version ? pinned.keys.reject { |k| pinned[k] == fresh[k] } : []
changed.each { |k| warn "#{k} asset for #{version} changed upstream: pinned #{pinned[k]}, now #{fresh[k]}" }
abort "Refusing to re-pin #{version}; edit the cask by hand if this replacement is legitimate" unless changed.empty?

updated = content.sub(/version "[^"]+"/, %(version "#{version}"))
updated = updated.sub(/(arm:\s+)"[0-9a-f]{64}"/) { %(#{Regexp.last_match(1)}"#{arm_sha}") }
updated = updated.sub(/(intel:\s+)"[0-9a-f]{64}"/) { %(#{Regexp.last_match(1)}"#{intel_sha}") }

raise "Failed to update #{path}: version" unless updated.include?(%(version "#{version}"))
raise "Failed to update #{path}: arm sha256" unless updated.include?(%("#{arm_sha}"))
raise "Failed to update #{path}: intel sha256" unless updated.include?(%("#{intel_sha}"))

# Write a complete, synced copy next to the cask and rename it into place, so a failed or
# interrupted write leaves the original untouched.
tmp = "#{path}.tmp-#{Process.pid}"
at_exit { File.unlink(tmp) if File.exist?(tmp) }
File.open(tmp, File::WRONLY | File::CREAT | File::EXCL, File.stat(path).mode & 0o7777) { |f| f.write(updated); f.flush; f.fsync }
File.rename(tmp, path)
lock.close
'

printf 'Updated %s to %s (arm %s, intel %s)\n' "${cask_path}" "${version}" "${arm_sha}" "${intel_sha}"
