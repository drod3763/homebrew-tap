cask "pocket-sync" do
  version "7.1.1"
  sha256 "05a90e085681906a0e3b2f7febfceae8288ab946c3024119e319cb7a3e2cd8f5"

  url "https://github.com/neil-morrison44/pocket-sync/releases/download/v#{version}/Pocket.Sync_#{version}_universal.dmg"
  name "Pocket Sync"
  desc "Manage cores, saves, screenshots and more on an Analogue Pocket"
  homepage "https://github.com/neil-morrison44/pocket-sync"

  livecheck do
    url :url
    strategy :github_latest
  end

  # The app ships Tauri's built-in updater (signed latest.json on GitHub Releases).
  auto_updates true
  depends_on macos: :monterey

  app "Pocket Sync.app"

  zap trash: [
    "~/Library/Application Support/today.neil.pocket-sync",
    "~/Library/Caches/today.neil.pocket-sync",
    "~/Library/Preferences/today.neil.pocket-sync.plist",
    "~/Library/Saved Application State/today.neil.pocket-sync.savedState",
    "~/Library/WebKit/today.neil.pocket-sync",
  ]
end
