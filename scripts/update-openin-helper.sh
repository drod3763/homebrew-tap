#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cask_path="${repo_root}/Casks/openin-helper.rb"

if [[ $# -gt 1 ]]
then
  printf 'Usage: %s [version]\n' "$0" >&2
  printf 'Examples:\n' >&2
  printf '  %s          # use latest from appcast\n' "$0" >&2
  printf '  %s 4.3.5    # pin specific version\n' "$0" >&2
  exit 1
fi

detect_latest() {
  ruby -rrexml/document -ropen-uri -e '
doc = REXML::Document.new(URI.open("https://loshadki.app/openin-helper4/releases/appcast.xml").read)
ns = { "sparkle" => "http://www.andymatuschak.org/xml-namespaces/sparkle" }

doc.elements.each("rss/channel/item") do |item|
  channel = item.elements["sparkle:channel", ns]
  next if channel && channel.text && !channel.text.strip.empty?

  version = item.elements["sparkle:shortVersionString", ns]&.text&.strip
  url = item.elements["enclosure"]&.attributes&.[]("url")&.strip
  next if version.nil? || version.empty? || url.nil? || url.empty?

  puts version
  puts url
  exit 0
end

warn "Could not find a stable appcast item"
exit 1
'
}

if [[ $# -eq 1 ]]
then
  version="$1"
  encoded_version="${version// /%20}"
  url="https://loshadki.app/openin-helper4/releases/OpenIn%20Helper%20${encoded_version}.zip"
else
  latest_data="$(detect_latest)"
  version="${latest_data%%$'\n'*}"
  url="${latest_data#*$'\n'}"
fi

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

CASK_PATH="${cask_path}" VERSION="${version}" SHA256="${sha256}" ruby -e '
path = ENV.fetch("CASK_PATH")
version = ENV.fetch("VERSION")
sha256 = ENV.fetch("SHA256")

content = File.read(path)
updated = content.gsub(/version "[^"]+"/, %(version "#{version}"))
updated = updated.gsub(/sha256 "[0-9a-f]{64}"/, %(sha256 "#{sha256}"))

unless updated.include?(%(version "#{version}")) && updated.include?(%(sha256 "#{sha256}"))
  raise "Failed to update #{path}"
end

File.write(path, updated)
'

printf 'Updated %s\n' "${cask_path}"
printf 'Version: %s\n' "${version}"
printf 'SHA256:  %s\n' "${sha256}"
