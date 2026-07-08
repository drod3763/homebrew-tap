class HerdrMx < Formula
  desc "Terminal workspace manager for AI coding agents (drod3763 fork)"
  homepage "https://github.com/drod3763/herdr-mx"
  version "0.7.3-mx.1"
  license "AGPL-3.0-or-later"
  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+-mx\.\d+)$/i)
    strategy :github_latest
  end

  # No bottle block: `revision 1` shifts the expected bottle filename to a
  # `_1`-suffixed name that was never built (the prior release only carries
  # revision-0 bottles), so a committed bottle block 404s. Without it, installs
  # use the checksum-verified (sha256) prebuilt binaries below. `brew pr-pull`
  # will re-add a matching bottle block on the next release.

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/drod3763/herdr-mx/releases/download/v0.7.3-mx.1/herdr-macos-aarch64"
      sha256 "bab13dc597bee78c6ef5d871986c354e3abf0b69ee7d84805b4cbe52eca4018c"
    else
      url "https://github.com/drod3763/herdr-mx/releases/download/v0.7.3-mx.1/herdr-macos-x86_64"
      sha256 "511d2625fc1ddd8b710b6df002e858f3acb3fa97f994644552d2d5db05503180"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/drod3763/herdr-mx/releases/download/v0.7.3-mx.1/herdr-linux-aarch64"
      sha256 "14e4affb5dacc81958a34037e89a8cddec0ae99c50a95d820530711cb55c1f0e"
    else
      url "https://github.com/drod3763/herdr-mx/releases/download/v0.7.3-mx.1/herdr-linux-x86_64"
      sha256 "be49274867b124ed2e2f55d6790b9a0d46a52999ed09eee57d3dd79ee3eacb39"
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
