cask "displaylink@16" do
  version "16.2,2026-07"
  sha256 "fd9eafab9542e592baa39984ed4e87e64e89f3de6b9a4429ab13a2334a7538e6"

  url "https://www.synaptics.com/sites/default/files/exe_files/#{version.csv.second}/DisplayLink%20Manager%20Graphics%20Connectivity#{version.csv.first}-EXE.pkg"
  name "DisplayLink USB Graphics Software"
  desc "Drivers for DisplayLink docks, adapters and monitors"
  homepage "https://www.synaptics.com/products/displaylink-graphics"

  # Last 16.x release, kept installable for rolling back from the upstream displaylink cask.
  livecheck do
    skip "Pinned to the 16.x series"
  end

  conflicts_with cask: "displaylink"
  depends_on macos: :sonoma

  pkg "DisplayLink Manager Graphics Connectivity#{version.csv.first}-EXE.pkg"

  uninstall launchctl: [
              "73YQY62QM3.com.displaylink.DisplayLinkAPServer",
              "com.displaylink.displaylinkmanager",
              "com.displaylink.useragent",
              "com.displaylink.useragent-prelogin",
              "com.displaylink.XpcService",
            ],
            quit:      "DisplayLinkUserAgent",
            pkgutil:   "com.displaylink.*",
            delete:    [
              "/Applications/DisplayLink",
              "/Library/LaunchAgents/com.displaylink.useragent-prelogin.plist",
              "/Library/LaunchAgents/com.displaylink.useragent.plist",
              "/Library/LaunchDaemons/com.displaylink.displaylinkmanager.plist",
            ]

  zap trash: [
    "~/Library/Application Scripts/73YQY62QM3.com.displaylink.DisplayLinkShared",
    "~/Library/Application Scripts/com.displaylink.DisplayLinkUserAgent",
    "~/Library/Containers/com.displaylink.DisplayLinkUserAgent",
    "~/Library/Group Containers/73YQY62QM3.com.displaylink.DisplayLinkShared",
  ]

  caveats do
    reboot
    license "https://www.synaptics.com/products/displaylink-graphics/downloads/macos-connectivity-#{version.csv.first}"
  end
end
