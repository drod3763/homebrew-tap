cask "quiver-launcher" do
  arch arm: "arm64", intel: "x64"

  version "3.5.1"
  sha256 arm:   "be091cb526402333605a0b19da7daf23dd397a7e58eb5a073cd75e35c49acd35",
         intel: "3feafb7e54a92044ccc6dab3a7e9bfc158393fae555f297447741f4975959509"

  url "https://github.com/tgeorgiadis/quiver-launcher/releases/download/v#{version}/QuiverLauncher-osx-#{arch}-Portable.zip"
  name "Quiver Launcher"
  desc "Launcher for community game ports, recompilations and recreations"
  homepage "https://quiverlauncher.com/"

  livecheck do
    url :url
    strategy :github_latest
  end

  # The app ships Velopack's updater (UpdateMac) and updates itself in place.
  auto_updates true
  depends_on macos: :monterey

  app "QuiverLauncher.app"

  # Upstream ships an ad-hoc-signed, unnotarized build, so Gatekeeper refuses to open it
  # once Homebrew quarantines the download. Strip the attribute while the bundle is still
  # staged (steps default to the staged dir); integrity is already pinned by sha256.
  preflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "QuiverLauncher.app"], chdir: "."
  end

  # The 3.x build is "portable": it keeps its library (settings, Cache/, installed Apps/)
  # beside the .app whenever that folder is writable, which for a cask means loose in
  # /Applications. It switches to ~/Library/Application Support/QuiverLauncher once that
  # folder holds a settings.json, so seed an empty one on first install. overwrite: false
  # never replaces an existing library there, and the guard leaves an existing portable
  # library in /Applications alone (it would win anyway).
  postflight_steps do
    unless_path_exists "settings.json", base: :appdir do
      write_file "Library/Application Support/QuiverLauncher/settings.json", "{}\n", base: :home, overwrite: false
    end
  end

  zap trash: [
    "~/Library/Application Support/QuiverLauncher",
    "~/Library/Caches/velopack/QuiverLauncher",
    "~/Library/Logs/velopack_QuiverLauncher.log",
    "~/Library/Preferences/com.QuiverLauncher.QuiverLauncher.plist",
  ]
end
