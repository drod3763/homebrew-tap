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

  # The Local Network grant binds to the ad-hoc signature of a specific build. A cask
  # cannot veto `brew upgrade`, so an upgrade does replace the granted bundle: the
  # already-running launcher keeps working (it is the old, granted build) until it
  # restarts, and the new build then prompts once more. Releases are rare on purpose.
  depends_on macos: :ventura

  app "Herdr Server.app"

  # The launcher only spawns /opt/homebrew/bin/herdr or /usr/local/bin/herdr (or
  # HERDR_SERVER_BIN). A hard `depends_on formula: "herdr"` would lock out users of the
  # tap's own herdr-mx fork (it conflicts_with "herdr"), so check for a binary instead and
  # fail the install with the actionable choice.
  #
  # Homebrew quarantines cask downloads; Gatekeeper then refuses to exec this ad-hoc-signed,
  # unnotarized launcher (SIGKILL directly, OS_REASON_EXEC under launchd), so the agent could
  # never start. Strip the attribute while the bundle is still staged (steps default to the
  # staged dir); the `app` move keeps it off. Integrity is already pinned by sha256.
  preflight_steps do
    unless_path_exists "{{HOMEBREW_PREFIX}}/bin/herdr" do
      unless_path_exists "/usr/local/bin/herdr" do
        run "/bin/sh", args: ["-c", "echo 'Herdr Server needs a herdr binary first: " \
                                    "brew install herdr (or drod3763/tap/herdr-mx)' >&2; exit 1"]
      end
    end
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "Herdr Server.app"], chdir: "."
  end

  # Deliberately no `uninstall launchctl:` for the agent: Homebrew runs the uninstall
  # procedure on every upgrade/reinstall too, which would boot out the launcher (stopping
  # the server and every pane under it) and delete a plist the dotfiles own. The caveats
  # cover the manual bootout on a real uninstall.

  # Not a `launchd` stanza: the agent is owned by the user's dotfiles (chezmoi), which also
  # retires `brew services start herdr` — the two would fight over the herdr socket.
  caveats <<~EOS
    Herdr Server is a launcher, not a GUI app. Run it from a user LaunchAgent so it
    stays the responsible parent of `herdr server`:

      #{appdir}/Herdr Server.app/Contents/MacOS/herdr-server-launcher

    Do not run `brew services start herdr` alongside it. The first LAN connection from a
    herdr pane prompts to allow "Herdr Server" on the local network. The install strips
    Homebrew's quarantine attribute from the bundle: it is ad-hoc signed and unnotarized,
    and Gatekeeper would otherwise refuse to run the launcher at all.

    Uninstalling? Unload the agent first so KeepAlive does not spin on a missing binary:
      launchctl bootout gui/$UID/local.herdr-server

    Upgrading this cask replaces the bundle, and the Local Network grant is bound to the
    previous build's signature. The running launcher keeps the old grant until it
    restarts; after that (or after `launchctl kickstart -k gui/$UID/local.herdr-server`),
    allow "Herdr Server" again when macOS prompts. See herdrdev/herdr#808.
  EOS
end
