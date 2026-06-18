class GitDeltaFork < Formula
  desc "Syntax-highlighting pager for git and diff output (drod3763 fork)"
  homepage "https://github.com/drod3763/delta"
  license "MIT"
  # Head-only: tracks the fork's feature branch. Install with `brew install --HEAD`.
  head "https://github.com/drod3763/delta.git", branch: "os-dark-light-detection"

  depends_on "rust" => :build

  # Installs the `delta` binary, which conflicts with the homebrew-core git-delta formula.
  conflicts_with "git-delta", because: "both install a `delta` binary"

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match "delta", shell_output("#{bin}/delta --version")
  end
end
