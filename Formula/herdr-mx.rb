class HerdrMx < Formula
  desc "Terminal workspace manager for AI coding agents (drod3763 fork)"
  homepage "https://github.com/drod3763/herdr-mx"
  version "0.7.1-mx.2"
  license "AGPL-3.0-or-later"
  revision 1

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+-mx\.\d+)$/i)
    strategy :github_latest
  end

  # No bottle block: `revision 1` shifts the expected bottle filename to a
  # `_1`-suffixed name that was never built (the prior release only carries
  # revision-0 bottles), so a committed bottle block 404s. Without it, installs
  # fall back to the signed prebuilt binaries below. `brew pr-pull` will
  # re-add a matching bottle block on the next release.

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/drod3763/herdr-mx/releases/download/v0.7.1-mx.2/herdr-macos-aarch64"
      sha256 "b0d9637044fd7518298e66a75ead0efe87df6fa5b888d362875d6a6173a9c0de"
    else
      url "https://github.com/drod3763/herdr-mx/releases/download/v0.7.1-mx.2/herdr-macos-x86_64"
      sha256 "5262f43155e286ee3f5879cb61a4c208139cbc1f96731de58411005ce843a33d"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/drod3763/herdr-mx/releases/download/v0.7.1-mx.2/herdr-linux-aarch64"
      sha256 "997c07d7d21671253e686c6e018e8763f327c5476d56bdc70801e49ddec04ef9"
    else
      url "https://github.com/drod3763/herdr-mx/releases/download/v0.7.1-mx.2/herdr-linux-x86_64"
      sha256 "e92775dedb4afeddb47d2bd9ac2241a2691009430c1c96d21b688194dc8f7bb7"
    end
  end

  # Installs the `herdr` binary, which would conflict with an upstream herdr formula.
  conflicts_with "herdr", because: "both install a `herdr` binary"

  def install
    # Release asset is a single bare binary whose name varies by platform.
    binaries = Dir["herdr-*"]
    odie "expected exactly one herdr-* asset, found #{binaries.length}" if binaries.length != 1
    bin.install binaries.first => "herdr"
    # An HTTP download of a naked binary does not carry the executable bit; set it explicitly.
    chmod 0555, bin/"herdr"
  end

  service do
    run [opt_bin/"herdr", "server"]
    keep_alive true
    log_path var/"log/herdr.log"
    error_log_path var/"log/herdr.log"
  end

  test do
    # `herdr --version` prints the full fork version (e.g. "herdr 0.7.1-mx.1"),
    # so assert against the formula version to stay correct across updates.
    assert_match version.to_s, shell_output("#{bin}/herdr --version")
  end
end
