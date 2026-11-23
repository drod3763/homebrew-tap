cask "quiver-launcher@beta" do
  version "4.0.0-beta.9"
  sha256 "2bf6daf36ffdee7f6f4b06f08d7684235ee963b584473d674e833b0a11d6c179"

  url "https://github.com/tgeorgiadis/quiver-launcher/releases/download/v#{version}/QuiverLauncher_#{version}_universal.dmg"
  name "Quiver Launcher Beta"
  desc "Launcher for community game ports, recompilations and recreations"
  homepage "https://quiverlauncher.com/"

  # Track prereleases too: the 4.x line only ships as GitHub prereleases for now.
  livecheck do
    url :url
    regex(/^v?(\d+(?:\.\d+)+(?:-beta\.\d+)?)$/i)
    strategy :github_releases do |json, regex|
      json.map do |release|
        next if release["draft"]

        release["tag_name"]&.[](regex, 1)
      end
    end
  end

  # No auto_updates: on macOS the 4.x app only points at the release page
  # (update.rs Kind::Elsewhere), so updates ship through `brew upgrade`.
  depends_on :macos

  app "Quiver Launcher.app"

  # Upstream ships an unsigned, unnotarized build, so Gatekeeper refuses to open it once
  # Homebrew quarantines the download. Strip the attribute while the bundle is still staged
  # (steps default to the staged dir); integrity is already pinned by sha256.
  preflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "Quiver Launcher.app"], chdir: "."
  end

  zap trash: [
    "~/Library/Application Support/com.quiverlauncher.app",
    "~/Library/Caches/com.quiverlauncher.app",
    "~/Library/WebKit/com.quiverlauncher.app",
  ]
end
