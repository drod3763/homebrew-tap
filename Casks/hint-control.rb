cask "hint-control" do
  arch arm: "aarch64", intel: "amd64"

  version "1.17.3"
  sha256 arm:   "ad38b065689d565a1cb283833d3fd8a14abd66b3aad42b84a8a49eb1decbd69d",
         intel: "98d5482a2945024f6af2979238dc46993cfe8e4b21aab39f686ff082adafc4e6"

  url "https://github.com/zacharee/HINTControl/releases/download/#{version}/hintcontrol-#{version}-mac-#{arch}.zip"
  name "HINT Control"
  desc "View and control T-Mobile Home Internet gateways"
  homepage "https://github.com/zacharee/HINTControl"

  livecheck do
    url :url
    strategy :github_latest
  end

  # The app ships a Sparkle updater (SUAutomaticallyUpdate) via its Conveyor packaging.
  auto_updates true
  depends_on :macos

  app "HINT Control.app"

  # Settings live in the JVM's shared com.apple.java.util.prefs.plist, which other Java
  # apps also use, so it is deliberately not zapped.
  zap trash: [
    "~/Library/Caches/dev.zwander.arcadyankvd21control",
    "~/Library/HTTPStorages/dev.zwander.arcadyankvd21control",
    "~/Library/Preferences/dev.zwander.arcadyankvd21control.plist",
    "~/Library/Saved Application State/dev.zwander.arcadyankvd21control.savedState",
  ]
end
