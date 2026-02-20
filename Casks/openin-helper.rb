cask "openin-helper" do
  version "4.3.5"
  sha256 "e986e044c2bc2e5939648877571f033d0931be04b296967fa323636f1d5c8f38"

  url "https://loshadki.app/openin-helper4/releases/OpenIn%20Helper%20#{version}.zip"
  name "OpenIn Helper"
  desc "Companion utility for OpenIn with extra integration features"
  homepage "https://loshadki.app/openin-helper4/"

  livecheck do
    url "https://loshadki.app/openin-helper4/releases/appcast.xml"
    strategy :sparkle
  end

  auto_updates true
  depends_on macos: ">= :sequoia"

  app "OpenIn Helper.app"
end
