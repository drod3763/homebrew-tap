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

# Fetch a GitHub API URL, adding the auth header only when a token is present (a token lifts
# the unauthenticated rate limit; the build job runs without one). A helper — rather than a
# conditionally-populated array spliced in with ${arr[@]+...} — keeps the token-optional path
# unambiguous under `set -u` on every bash version.
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
  # Normalize to lowercase (GitHub accepts uppercase SHAs; users paste them). tr keeps this
  # working on macOS Bash 3.2, which lacks the ${var,,} lowercasing operator.
  commit="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  if [[ ! "${commit}" =~ ^[0-9a-f]{40}$ ]]
  then
    printf 'commit sha must be 40 hex chars\n' >&2
    exit 1
  fi
  commit_json="$(gh_api_get "https://api.github.com/repos/${owner}/${repo}/commits/${commit}")"
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
  commit_json="$(gh_api_get "${api_url}")"
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

# Git committer dates are author-controlled and not guaranteed to increase with path history,
# and a manually-pinned (or backdated) commit could be older than what's shipped. Refuse to
# write a version below the current cask version so `brew upgrade` never silently stalls on a
# downgrade; an equal version (idempotent re-run) is fine. Edit the cask by hand for a
# deliberate rollback.
current_version="$(sed -n 's/.*version "\([^",]*\),.*/\1/p' "${cask_path}" | head -1)"
version_compare='exit(Gem::Version.new(ARGV[0]) >= Gem::Version.new(ARGV[1]) ? 0 : 1)'
if [[ -n "${current_version}" ]] && ! ruby -e "${version_compare}" "${version}" "${current_version}"
then
  printf 'New version %s is lower than the current cask version %s (backdated/older commit?).\n' \
    "${version}" "${current_version}" >&2
  printf 'Refusing to write a downgrade. Edit the cask manually for an intentional rollback.\n' >&2
  exit 1
fi

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
# root-running package. Requires macOS (hdiutil/pkgutil); off-platform it fails closed and
# refuses to write unless AMPHETAMINE_PP_ALLOW_UNVERIFIED=1 is set (see the else branch below).
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

  # --expand-full also extracts the payload (not just the BOM/scripts) so the privileged
  # sudoers file's contents can be pinned below.
  pkgutil --expand-full "${mount_point}/${expected_pkg}" "${work_dir}/pkg"
  # Enumerate ALL component receipts and require the set to be exactly the one the cask
  # uninstalls. Matching just the first id (head -1) would let a future multi-component
  # product pkg pass while Homebrew installs extra components the cask never removes —
  # leaving files or privileged config behind on uninstall.
  found_ids="$(find "${work_dir}/pkg" -name PackageInfo -exec \
    sed -n 's/.*identifier="\([^"]*\)".*/\1/p' {} + 2>/dev/null | sort -u)"

  if [[ "${found_ids}" != "${expected_id}" ]]
  then
    printf 'DMG pkg component receipts do not match exactly the cask receipt.\n' >&2
    printf '  expected only: %s\n  found:\n%s\nRefusing update.\n' \
      "${expected_id}" "${found_ids}" >&2
    exit 1
  fi

  # Freeze the installer's pre/postinstall and distribution scripts. Pkg scripts run
  # privileged and can create files outside the BOM (another sudoers drop-in, a LaunchDaemon)
  # that `brew uninstall` would not remove. Receipt/signature checks don't cover that. The
  # DMG sha256 pins today's bytes, but the auto-updater would otherwise silently accept a
  # future commit whose scripts changed — so pin a digest of every install script and refuse
  # on any change, forcing a human to review new scripts before re-baselining this value.
  # The digest binds each script's relative path (its entrypoint name — preinstall vs
  # postinstall, component location) to its content, so a rename or a phase swap of two
  # same-content scripts also trips it.
  expected_scripts_digest="7400fd20105c95bf62be7af38a76da2880dbfb42b85359e8f02e1176a8066d45"
  scripts_digest="$( (cd "${work_dir}/pkg" && find . -path '*/Scripts/*' -type f -exec shasum -a 256 {} +) |
    sort | shasum -a 256 | cut -d' ' -f1)"
  if [[ "${scripts_digest}" != "${expected_scripts_digest}" ]]
  then
    printf 'Installer scripts changed (digest %s, expected %s).\n' \
      "${scripts_digest}" "${expected_scripts_digest}" >&2
    printf 'Review the new pre/postinstall scripts for privileged side effects, then update\n' >&2
    printf 'expected_scripts_digest. Refusing update.\n' >&2
    exit 1
  fi

  # Pin the installed payload's PATHS plus their mode/owner/group (lsbom -p fMUG), not their
  # contents. `uninstall pkgutil:` already removes every BOM path, but a new privileged path
  # (a LaunchDaemon, an extra sudoers drop-in) or a permission/ownership change on an existing
  # one — e.g. a world-writable or non-root sudoers file, which sudo would ignore or which is
  # a vuln — is a privilege change that warrants human review. Freezing path+metadata refuses
  # those while still allowing content updates to existing files (pinned by the DMG sha256).
  expected_payload_digest="46f288ec0f92016a98da6031662d305eb909dce8e6a9d692ae2802fbcf6fae22"
  payload_digest="$(find "${work_dir}/pkg" -name Bom -exec lsbom -p fMUG {} + |
    sort -u | shasum -a 256 | cut -d' ' -f1)"
  if [[ "${payload_digest}" != "${expected_payload_digest}" ]]
  then
    printf 'Installer payload paths or file metadata changed (digest %s, expected %s).\n' \
      "${payload_digest}" "${expected_payload_digest}" >&2
    printf 'A new/removed path or a mode/owner change on a privileged file (e.g. the sudoers\n' >&2
    printf 'drop-in) needs human review, then update expected_payload_digest. Refusing update.\n' >&2
    exit 1
  fi

  # Pin the CONTENTS of the two files that define this package's privileged behavior: the
  # sudoers grant (the passwordless-sudo rule) and powerProtect.scpt (the AppleScript that
  # exercises it). The path/metadata pin above can't see a rule that widens NOPASSWD scope
  # within the same file, nor a rewrite of the script logic. Because the open-pr diff-gate
  # surfaces only version/sha changes, an unpinned content change would be invisible to PR
  # review — so freeze both and require a human to review any change before re-baselining.
  expected_sudoers_digest="ec97dfc137afb5278e01a069f96bf8ecc3862250f07fc0d00b0d9a330a3c5e93"
  expected_scpt_digest="c616365813186116ddc73be8294a446f818464c13b2570525a15fd2162458300"
  sudoers_file="$(find "${work_dir}/pkg" -path '*/sudoers.d/amphetamine_PowerProtect' -type f | head -1)"
  scpt_file="$(find "${work_dir}/pkg" -path '*/com.if.Amphetamine/powerProtect.scpt' -type f | head -1)"
  if [[ -z "${sudoers_file}" || -z "${scpt_file}" ]]
  then
    printf 'sudoers drop-in or powerProtect.scpt not found in the expanded payload; refusing update\n' >&2
    exit 1
  fi
  sudoers_digest="$(shasum -a 256 "${sudoers_file}" | cut -d' ' -f1)"
  if [[ "${sudoers_digest}" != "${expected_sudoers_digest}" ]]
  then
    printf 'sudoers grant contents changed (digest %s, expected %s).\n' \
      "${sudoers_digest}" "${expected_sudoers_digest}" >&2
    printf 'Review the new NOPASSWD rule for scope changes, then update expected_sudoers_digest.\n' >&2
    printf 'Refusing update.\n' >&2
    exit 1
  fi
  scpt_digest="$(shasum -a 256 "${scpt_file}" | cut -d' ' -f1)"
  if [[ "${scpt_digest}" != "${expected_scpt_digest}" ]]
  then
    printf 'powerProtect.scpt contents changed (digest %s, expected %s).\n' \
      "${scpt_digest}" "${expected_scpt_digest}" >&2
    printf 'Review the new script (it drives the passwordless-sudo grant), then update\n' >&2
    printf 'expected_scpt_digest. Refusing update.\n' >&2
    exit 1
  fi

  printf 'Verified DMG ships "%s" (receipt %s, notarized, Developer ID %s; scripts, paths, sudoers & scpt pinned)\n' \
    "${expected_pkg}" "${expected_id}" "${expected_team_id}"
elif [[ "${AMPHETAMINE_PP_ALLOW_UNVERIFIED:-}" == "1" ]]
then
  printf 'WARNING: hdiutil/pkgutil unavailable and AMPHETAMINE_PP_ALLOW_UNVERIFIED=1 set; writing cask WITHOUT pkg contract/signature verification\n' >&2
else
  # Fail closed: this cask installs a root-running, sudoers-writing pkg. Refuse to mint a
  # version/SHA bump we could not verify (wrong pkg, tampered payload, missing notarization).
  # Run on macOS (hdiutil/pkgutil), or set AMPHETAMINE_PP_ALLOW_UNVERIFIED=1 to override.
  printf 'ERROR: cannot verify the pkg contract without hdiutil/pkgutil (needs macOS); refusing to update. Set AMPHETAMINE_PP_ALLOW_UNVERIFIED=1 to override.\n' >&2
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
