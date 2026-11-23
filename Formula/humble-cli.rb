class HumbleCli < Formula
  desc "CLI for downloading your Humble Bundle purchases"
  homepage "https://github.com/smbl64/humble-cli"
  url "https://github.com/smbl64/humble-cli/archive/refs/tags/v2.0.1.tar.gz"
  sha256 "d6b1efb45383ed206f93eee3dc4697a4a955455d52d99fec1d6137dfc07e8b42"
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
