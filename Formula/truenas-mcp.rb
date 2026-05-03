class TruenasMcp < Formula
  desc "MCP server enabling AI models to interact with the TrueNAS API"
  homepage "https://github.com/truenas/truenas-mcp"
  url "https://github.com/truenas/truenas-mcp/archive/refs/tags/v0.0.4.tar.gz"
  sha256 "4c6c09317f1b705d11f9c3d6b5481cbc122c9aae911eecb103df6e7665f97b63"
  license "GPL-3.0-only"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(ldflags: "-s -w"), "./cmd/truenas-mcp"
  end

  test do
    assert_match "truenas-mcp version", shell_output("#{bin}/truenas-mcp --version")
  end
end
