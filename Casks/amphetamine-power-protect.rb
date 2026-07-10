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

  depends_on macos: :big_sur

  pkg "Install Power Protect.pkg"

  # `uninstall pkgutil:` removes every file recorded in the package receipt (BOM) as root,
  # then forgets the receipt — not merely `pkgutil --forget`. That deletes the privileged
  # drop-in /private/etc/sudoers.d/amphetamine_PowerProtect on a normal `brew uninstall`, so
  # no sudoers config is left behind. The per-user powerProtect.scpt is moved out of the
  # receipt's path by the pkg's postinstall (into ~/Library), so it isn't in the BOM; it's a
  # non-privileged user leftover cleaned by `zap` below.
  uninstall pkgutil: "com.if.pkg.AmphetaminePowerProtect"

  zap trash: "~/Library/Application Scripts/com.if.Amphetamine/powerProtect.scpt"
end
