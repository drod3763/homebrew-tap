class TruenasMcp < Formula
  desc "MCP server enabling AI models to interact with the TrueNAS API"
  homepage "https://github.com/truenas/truenas-mcp"
  url "https://github.com/truenas/truenas-mcp/archive/refs/tags/v0.0.7.tar.gz"
  sha256 "e665f59359c65383d9ab94a01dc65289c3a65cf5c02c07995ea8da1d31f1b553"
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
