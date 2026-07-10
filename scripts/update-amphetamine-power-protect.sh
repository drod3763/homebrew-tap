#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cask_path="${repo_root}/Casks/amphetamine-power-protect.rb"

owner="x74353"
repo="Amphetamine-Power-Protect"
# The GitHub API path param and the raw download URL both want the space percent-encoded.
dmg_path_encoded="DMG/Power%20Protect%20for%20Amphetamine.dmg"

if [[ $# -gt 1 ]]
then
  printf 'Usage: %s [commit-sha]\n' "$0" >&2
  printf 'Examples:\n' >&2
  printf '  %s                                          # latest commit touching the DMG\n' "$0" >&2
  printf '  %s 895cfd55042cef4ccbe15741d022456ddd9bb2e3  # pin a specific commit\n' "$0" >&2
  exit 1
fi

# Optional token lifts the unauthenticated GitHub API rate limit (used in CI).
auth_args=()
if [[ -n "${GITHUB_TOKEN:-}" ]]
then
  auth_args=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

if [[ $# -eq 1 ]]
then
  commit="$1"
  if [[ ! "${commit}" =~ ^[0-9a-f]{40}$ ]]
  then
    printf 'commit sha must be 40 lowercase hex chars\n' >&2
    exit 1
  fi
  commit_json="$(curl -fsSL "${auth_args[@]+"${auth_args[@]}"}" \
    "https://api.github.com/repos/${owner}/${repo}/commits/${commit}")"
  date="$(printf '%s' "${commit_json}" |
    ruby -rjson -e 'puts JSON.parse(STDIN.read).dig("commit", "committer", "date").to_s')"
else
  # Encode the path param so the space survives the query string intact.
  api_url="https://api.github.com/repos/${owner}/${repo}/commits?path=${dmg_path_encoded}&per_page=1"
  commit_json="$(curl -fsSL "${auth_args[@]+"${auth_args[@]}"}" "${api_url}")"
  commit_line="$(printf '%s' "${commit_json}" | ruby -rjson -e '
    arr = JSON.parse(STDIN.read)
    raise "no commits found for DMG path" if !arr.is_a?(Array) || arr.empty?
    c = arr[0]
    puts "#{c.fetch("sha")} #{c.dig("commit", "committer", "date")}"
  ')"
  read -r commit date <<<"${commit_line}"
fi

if [[ ! "${commit}" =~ ^[0-9a-f]{40}$ ]]
then
  printf 'Could not resolve a valid commit sha (got: %s)\n' "${commit}" >&2
  exit 1
fi

if [[ ! "${date}" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2}) ]]
then
  printf 'Could not read commit date (got: %s)\n' "${date}" >&2
  exit 1
fi

# Commit timestamp -> cask version YYYY.MM.DD.HHMMSS. Using the full time (not just the
# date) keeps the version monotonic even if upstream replaces the DMG more than once on the
# same UTC day, so brew upgrade always orders a newer installer higher.
version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.${BASH_REMATCH[4]}${BASH_REMATCH[5]}${BASH_REMATCH[6]}"
url="https://raw.githubusercontent.com/${owner}/${repo}/${commit}/${dmg_path_encoded}"

if command -v shasum >/dev/null 2>&1
then
  sha256="$(curl -fL "${url}" | shasum -a 256 | cut -d' ' -f1)"
elif command -v sha256sum >/dev/null 2>&1
then
  sha256="$(curl -fL "${url}" | sha256sum | cut -d' ' -f1)"
else
  printf 'Need shasum or sha256sum in PATH\n' >&2
  exit 1
fi

# The cask URL interpolates version.after_comma, so only the version + sha256 lines change.
# version is "<date>,<commit>": the date drives brew upgrade ordering, the commit pins the URL.
CASK_PATH="${cask_path}" COMMIT="${commit}" VERSION="${version}" SHA256="${sha256}" ruby -e '
path = ENV.fetch("CASK_PATH")
commit = ENV.fetch("COMMIT")
version = ENV.fetch("VERSION")
sha256 = ENV.fetch("SHA256")

content = File.read(path)
updated = content.gsub(/version "[^"]+"/, %(version "#{version},#{commit}"))
updated = updated.gsub(/sha256 "[0-9a-f]{64}"/, %(sha256 "#{sha256}"))

unless updated.include?(%(version "#{version},#{commit}")) &&
       updated.include?(%(sha256 "#{sha256}"))
  raise "Failed to update #{path}"
end

File.write(path, updated)
'

printf 'Updated %s\n' "${cask_path}"
printf 'Commit:  %s\n' "${commit}"
printf 'Version: %s\n' "${version}"
printf 'SHA256:  %s\n' "${sha256}"
