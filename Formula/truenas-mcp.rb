class TruenasMcp < Formula
  desc "MCP server enabling AI models to interact with the TrueNAS API"
  homepage "https://github.com/truenas/truenas-mcp"
  url "https://github.com/truenas/truenas-mcp/archive/refs/tags/v0.0.6.tar.gz"
  sha256 "012e5195b5842c3b9ca62bb29ba7b349966fd15f449b189c4b4732594a39f9c0"
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
