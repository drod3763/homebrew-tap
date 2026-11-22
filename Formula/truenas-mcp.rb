class TruenasMcp < Formula
  desc "MCP server enabling AI models to interact with the TrueNAS API"
  homepage "https://github.com/truenas/truenas-mcp"
  url "https://github.com/truenas/truenas-mcp/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "100e70f8ad9fe98524a7de3eb602f8a882bbce9aa5c3ea58f3852bf85dff4f5c"
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
