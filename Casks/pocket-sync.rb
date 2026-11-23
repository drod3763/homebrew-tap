cask "pocket-sync" do
  version "7.2.1"
  sha256 "2c82fa294ef66d08f9596cd129e13424881ec1de731aba48509549c5bbaefe2e"

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
