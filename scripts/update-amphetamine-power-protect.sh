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
  # Refuse a manually-pinned commit that did not actually change the DMG: otherwise it would
  # mint a newer cask version for identical installer bytes, which a later real-DMG-commit
  # auto-update could then look like a downgrade against. The auto path already filters by
  # this path, so this guard only matters for an explicit SHA argument.
  date="$(printf '%s' "${commit_json}" | ruby -rjson -e '
    c = JSON.parse(STDIN.read)
    files = (c["files"] || []).map { |f| f["filename"] }
    unless files.include?("DMG/Power Protect for Amphetamine.dmg")
      STDERR.puts "commit #{ARGV[0]} does not modify the DMG; refusing to pin a version to unrelated bytes"
      exit 1
    end
    puts c.dig("commit", "committer", "date").to_s
  ' "${commit}")"
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

# Download once to a temp file so the same bytes are both hashed and contract-verified.
work_dir="$(mktemp -d)"
mount_point=""
cleanup() {
  if [[ -n "${mount_point}" && -d "${mount_point}" ]]
  then
    hdiutil detach "${mount_point}" >/dev/null 2>&1 || true
  fi
  rm -rf "${work_dir}"
}
trap cleanup EXIT

dmg_file="${work_dir}/installer.dmg"
curl -fL "${url}" -o "${dmg_file}"

if command -v shasum >/dev/null 2>&1
then
  sha256="$(shasum -a 256 "${dmg_file}" | cut -d' ' -f1)"
elif command -v sha256sum >/dev/null 2>&1
then
  sha256="$(sha256sum "${dmg_file}" | cut -d' ' -f1)"
else
  printf 'Need shasum or sha256sum in PATH\n' >&2
  exit 1
fi

# Verify the DMG still ships the exact pkg the cask installs: notarized + signed by the
# fork author's Developer ID (primary guard), plus the pkg filename and receipt id the cask
# hardcodes in its `pkg` / `uninstall pkgutil:` stanzas (secondary guards). Without this a
# scheduled update would accept any future upstream DMG that merely downloads — style/audit
# never mount or install it — and could auto-open a passing PR that installs a tampered
# root-running package. Requires macOS (hdiutil/pkgutil); elsewhere it warns and skips
# (fail-open only off-platform, where mounting an Apple DMG isn't possible).
expected_pkg="$(sed -n 's/^[[:space:]]*pkg "\(.*\)"[[:space:]]*$/\1/p' "${cask_path}" | head -1)"
# Receipt id lives in the `pkgutil:` stanza, which is an anchored Regexp (%r{\A...\z}); grab
# the com.if.pkg.* token whether the dots are escaped (regexp) or bare (plain string), then
# drop backslashes to recover the literal id.
expected_id="$(grep -oE 'com\\?\.if\\?\.pkg\\?\.[A-Za-z0-9]+' "${cask_path}" | head -1 | sed 's/\\//g')"

if [[ -z "${expected_pkg}" || -z "${expected_id}" ]]
then
  printf 'Could not read expected pkg name / receipt id from %s\n' "${cask_path}" >&2
  exit 1
fi

if command -v hdiutil >/dev/null 2>&1 && command -v pkgutil >/dev/null 2>&1
then
  mount_point="${work_dir}/mnt"
  mkdir -p "${mount_point}"
  hdiutil attach -readonly -nobrowse -mountpoint "${mount_point}" "${dmg_file}" >/dev/null

  if [[ ! -f "${mount_point}/${expected_pkg}" ]]
  then
    printf 'DMG does not contain expected pkg "%s" — upstream layout changed; refusing update\n' \
      "${expected_pkg}" >&2
    exit 1
  fi

  # Primary trust anchor: the pkg is notarized and signed by the fork author's Apple
  # Developer ID. The receipt/filename checks below are strings a compromised upstream could
  # preserve while swapping the root-running payload; the signature it cannot forge. Fail
  # closed unless the installer is Apple-notarized AND signed by this Team ID.
  expected_team_id="U5SR49N3PT" # Developer ID Installer: William Gustafson
  signature="$(pkgutil --check-signature "${mount_point}/${expected_pkg}" 2>&1)"
  if ! printf '%s' "${signature}" | grep -q "trusted by the Apple notary service"
  then
    printf 'pkg is not notarized by Apple; refusing update\n%s\n' "${signature}" >&2
    exit 1
  fi
  if ! printf '%s' "${signature}" | grep -q "(${expected_team_id})"
  then
    printf 'pkg not signed by expected Developer ID %s; refusing update\n%s\n' \
      "${expected_team_id}" "${signature}" >&2
    exit 1
  fi

  pkgutil --expand "${mount_point}/${expected_pkg}" "${work_dir}/pkg"
  found_id="$(find "${work_dir}/pkg" -name PackageInfo -exec \
    sed -n 's/.*identifier="\([^"]*\)".*/\1/p' {} + 2>/dev/null | head -1)"

  if [[ "${found_id}" != "${expected_id}" ]]
  then
    printf 'DMG pkg receipt id "%s" does not match expected "%s"; refusing update\n' \
      "${found_id}" "${expected_id}" >&2
    exit 1
  fi
  printf 'Verified DMG ships "%s" (receipt %s, notarized, Developer ID %s)\n' \
    "${expected_pkg}" "${expected_id}" "${expected_team_id}"
elif [[ "${AMPHETAMINE_PP_ALLOW_UNVERIFIED:-}" == "1" ]]
then
  printf 'WARNING: hdiutil/pkgutil unavailable and AMPHETAMINE_PP_ALLOW_UNVERIFIED=1 set; '\
'writing cask WITHOUT pkg contract/signature verification\n' >&2
else
  # Fail closed: this cask installs a root-running, sudoers-writing pkg. Refuse to mint a
  # version/SHA bump we could not verify (wrong pkg, tampered payload, missing notarization).
  # Run on macOS (hdiutil/pkgutil), or set AMPHETAMINE_PP_ALLOW_UNVERIFIED=1 to override.
  printf 'ERROR: cannot verify the pkg contract without hdiutil/pkgutil (needs macOS); '\
'refusing to update. Set AMPHETAMINE_PP_ALLOW_UNVERIFIED=1 to override.\n' >&2
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
