cask "rex" do
  version "0.1.0,1632"
  sha256 "5774f134917718453cc7c414da497e8295ba30b86cd1f72f86b935b4e815e4fd"

  url "https://blob.superlogical.com/public/rex-app/snapshot/Rex-#{version.csv.first}-#{version.csv.second}.dmg"
  name "Rex"
  desc "Desktop app from Superlogical (snapshot channel)"
  homepage "https://www.superlogical.com/rex"

  livecheck do
    url "https://blob.superlogical.com/public/rex-app/snapshot/appcast.xml"
    strategy :sparkle
  end

  # The app ships Sparkle's updater against the same snapshot appcast.
  auto_updates true
  depends_on macos: :sequoia

  app "Rex Beta.app"

  zap trash: [
    "~/Library/Application Support/com.superlogical.rex",
    "~/Library/Caches/com.superlogical.rex",
    "~/Library/HTTPStorages/com.superlogical.rex",
    "~/Library/Preferences/com.superlogical.rex.plist",
    "~/Library/Saved Application State/com.superlogical.rex.savedState",
  ]
end
