cask "amphetamine-power-protect" do
  # Upstream ships no releases; the DMG lives on `main`. version.csv.second pins the
  # commit SHA (immutable, so the sha256 is stable), while the commit timestamp before the
  # comma (YYYY.MM.DD.HHMMSS) is the human-facing version that drives `brew upgrade`
  # ordering monotonically, even for multiple DMG commits on the same day.
  version "2023.12.07.162415,895cfd55042cef4ccbe15741d022456ddd9bb2e3"
  sha256 "f5627906d61f141c73743ca37c4588fc79fcf2a163ef5f8f562fb7e0e85eb2ca"

  url "https://raw.githubusercontent.com/x74353/Amphetamine-Power-Protect/#{version.csv.second}/DMG/Power%20Protect%20for%20Amphetamine.dmg",
      verified: "raw.githubusercontent.com/x74353/Amphetamine-Power-Protect/"
  name "Power Protect for Amphetamine"
  desc "Closed-Display Mode power-transition fix for the Amphetamine app"
  homepage "https://x74353.github.io/Amphetamine-Power-Protect/"

  # Upstream scopes Power Protect to Apple Silicon laptops (the Closed-Display Mode power
  # bug is Apple-Silicon-specific). Gate on arm64 so Intel machines can't install a
  # passwordless-sudo grant they have no need for — least privilege for a root-running pkg.
  depends_on arch:  :arm64
  depends_on macos: :big_sur

  pkg "Install Power Protect.pkg"

  # `uninstall pkgutil:` removes every file recorded in the package receipt (BOM) as root,
  # then forgets the receipt — not merely `pkgutil --forget`. That already deletes the
  # privileged drop-in on a normal `brew uninstall`. The explicit `delete:` is belt-and-
  # suspenders for that one security-sensitive path: it guarantees the sudoers file is
  # removed even if a future upstream package installed it via a script (so it wouldn't be
  # BOM-owned) rather than as payload — a privileged config must never be left behind. The
  # per-user powerProtect.scpt is moved out of the receipt path by the pkg's postinstall
  # (into ~/Library), so it isn't in the BOM; it's a non-privileged user leftover cleaned by
  # `zap` below.
  # Anchored, dot-escaped Regexp: `pkgutil:` is matched as a regex, so a bare string would
  # treat each `.` as a wildcard and match unanchored — letting an unrelated receipt id be
  # selected and its files removed as root. \A...\z pins it to exactly this package id.
  uninstall pkgutil: /\Acom\.if\.pkg\.AmphetaminePowerProtect\z/,
            delete:  "/private/etc/sudoers.d/amphetamine_PowerProtect"

  zap trash: "~/Library/Application Scripts/com.if.Amphetamine/powerProtect.scpt"

  # Power Protect is a companion to the Amphetamine app, and the installer's own preflight
  # refuses to run unless Amphetamine is present (the pkg aborts with an opaque volume error
  # otherwise). Amphetamine ships only on the Mac App Store, so it can't be a `depends_on`;
  # surface the prerequisite here so users install it first instead of hitting that failure.
  caveats <<~EOS
    Power Protect requires the Amphetamine app. Install it from the Mac App Store first —
    the installer refuses to run without it:
      https://apps.apple.com/app/amphetamine/id937984704
  EOS
end
