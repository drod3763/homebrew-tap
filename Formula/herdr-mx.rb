class HerdrMx < Formula
  desc "Terminal workspace manager for AI coding agents (drod3763 fork)"
  homepage "https://github.com/drod3763/herdr-mx"
  version "0.7.1-mx.1"
  license "AGPL-3.0-or-later"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+-mx\.\d+)$/i)
    strategy :github_latest
  end

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/drod3763/herdr-mx/releases/download/v0.7.1-mx.1/herdr-macos-aarch64"
      sha256 "3081e1814db3697193fcc9621f1fc7cd9418b5ffeecb62c4fd257288b63ccfd2"
    else
      url "https://github.com/drod3763/herdr-mx/releases/download/v0.7.1-mx.1/herdr-macos-x86_64"
      sha256 "bf36790cd9fc7a7b56b055109054afe414833c6b1cd8f2e10da042378e70fc93"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/drod3763/herdr-mx/releases/download/v0.7.1-mx.1/herdr-linux-aarch64"
      sha256 "a7eb2e21089bd58a1d8cd8b6d66a583d137b8899d2335b66b51a2febe45074fd"
    else
      url "https://github.com/drod3763/herdr-mx/releases/download/v0.7.1-mx.1/herdr-linux-x86_64"
      sha256 "734886a0e2d110417ed4c4fd408dc0cc3dfc8fd17c0fd02a6fd03350d0af4992"
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

  test do
    # `herdr --version` prints the full fork version (e.g. "herdr 0.7.1-mx.1"),
    # so assert against the formula version to stay correct across updates.
    assert_match version.to_s, shell_output("#{bin}/herdr --version")
  end
end
