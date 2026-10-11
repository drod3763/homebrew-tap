class HumbleCli < Formula
  desc "CLI for downloading your Humble Bundle purchases"
  homepage "https://github.com/smbl64/humble-cli"
  url "https://github.com/smbl64/humble-cli/archive/refs/tags/v0.23.2.tar.gz"
  sha256 "1376ae8f071f48d389637147bb26967a24dc8a25513a78796947fff5af40b5bd"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(ldflags: "-s -w -X main.version=#{version}"), "./cmd/humble-cli"
    generate_completions_from_executable(bin/"humble-cli", "completion")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/humble-cli --version")
  end
end
