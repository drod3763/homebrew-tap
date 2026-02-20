class Rar < Formula
  desc "Command-line archive manager for RAR and ZIP files"
  homepage "https://www.rarlab.com/"
  version "7.20"
  license :cannot_represent

  if Hardware::CPU.arm?
    url "https://www.win-rar.com/fileadmin/winrar-versions/rarmacos-arm-720.tar.gz"
    sha256 "e0e363c8f7b48f0dad54deabd1dc462a300ab740226e9eb2c091edbd2e05bd4a"
  else
    url "https://www.win-rar.com/fileadmin/winrar-versions/rarmacos-x64-720.tar.gz"
    sha256 "2e12d8f64b93b30702e38ddae4bfb063b9c73888599fa0aac8a5aa99f8d766de"
  end

  def install
    bin.install "rar", "unrar"
    pkgshare.install "acknow.txt", "default.sfx", "license.txt", "order.htm"
    pkgshare.install "rar.txt", "rarfiles.lst", "readme.txt", "whatsnew.txt"
  end

  test do
    assert_path_exists bin/"rar"
    assert_path_exists bin/"unrar"
  end
end
