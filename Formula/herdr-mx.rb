class HerdrMx < Formula
  desc "Terminal workspace manager for AI coding agents (drod3763 fork)"
  homepage "https://github.com/drod3763/herdr-mx"
  version "0.7.1-mx.2"
  license "AGPL-3.0-or-later"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+-mx\.\d+)$/i)
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/drod3763/homebrew-tap/releases/download/herdr-mx-0.7.1-mx.2"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "c3bceb3c860254d4d20772ec434c43f6e03d9cc97bcb9f1e8df8cea69069ecfb"
    sha256 cellar: :any_skip_relocation, sequoia:      "84deba58c7396d595ce33b2184707e0f26096ac3f7845995c4aa11f38002ea52"
    sha256 cellar: :any_skip_relocation, arm64_linux:  "d1a40972654825866bee85f58dc55d6b7bbd8bf26c9d0066102d1c7cd17f7192"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "7c9bc1f66ee6bbf3915a01f63b5c2728fdc6a2692ebd4e79f53f773f529a93d1"
  end

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

  test do
    # `herdr --version` prints the full fork version (e.g. "herdr 0.7.1-mx.1"),
    # so assert against the formula version to stay correct across updates.
    assert_match version.to_s, shell_output("#{bin}/herdr --version")
  end
end
