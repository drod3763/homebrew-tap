cask "herdr-server" do
  version "0.1.0"
  sha256 "9b8d6d4bbbf7ba6babc2e61fe8f0ee40f884d8ccf6fb703810a9953bb5fb16bd"

  url "https://github.com/drod3763/herdr-server-app/releases/download/v#{version}/Herdr-Server-#{version}.zip"
  name "Herdr Server"
  desc "Bundled parent for herdr server so it can be granted Local Network consent"
  homepage "https://github.com/drod3763/herdr-server-app"

  livecheck do
    url :url
    strategy :github_latest
  end

  # The Local Network grant binds to the ad-hoc signature of a specific build, so the app
  # must never be swapped underneath a user silently; upgrades are explicit and re-prompt.
  auto_updates false
  # The launcher only spawns /opt/homebrew/bin/herdr or /usr/local/bin/herdr (or
  # HERDR_SERVER_BIN); without the formula the LaunchAgent would just crash-loop.
  depends_on formula: "herdr"
  depends_on macos: :ventura

  app "Herdr Server.app"

  # Not a `launchd` stanza: the agent is owned by the user's dotfiles (chezmoi), which also
  # retires `brew services start herdr` — the two would fight over the herdr socket.
  caveats <<~EOS
    Herdr Server is a launcher, not a GUI app. Run it from a user LaunchAgent so it
    stays the responsible parent of `herdr server`:

      #{appdir}/Herdr Server.app/Contents/MacOS/herdr-server-launcher

    Do not run `brew services start herdr` alongside it. The first LAN connection from a
    herdr pane prompts to allow "Herdr Server" on the local network; after upgrading this
    cask, macOS will ask again because the grant is bound to the previous build's signature.
    See herdrdev/herdr#808.
  EOS
end
