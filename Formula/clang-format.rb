class ClangFormat < Formula
  desc "Formatting tools for C, C++, Obj-C, Java, JavaScript, TypeScript"
  homepage "https://clang.llvm.org/docs/ClangFormat.html"
  # The LLVM Project is under the Apache License v2.0 with LLVM Exceptions
  license "Apache-2.0"
  version_scheme 1
  head "https://github.com/llvm/llvm-project.git", branch: "main"

  stable do
    url "https://github.com/llvm/llvm-project/releases/download/llvmorg-14.0.2/llvm-14.0.2.src.tar.xz"
    sha256 "46811f451d0074836bd0a04afcd15942d85daba8520901fd5a3a57cf0945d482"

    resource "clang" do
      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-14.0.2/clang-14.0.2.src.tar.xz"
      sha256 "960578b785ed66a418248dd26ce49fcc10240e5d97bba4b0670a14d0d2c86592"
    end
  end

  livecheck do
    url :stable
    strategy :github_latest
    regex(%r{href=.*?/tag/llvmorg[._-]v?(\d+(?:\.\d+)+)}i)
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_monterey: "febf72ae3e52e5938675832a0ee73e5c95b234fa0d0009737ac19fb571f2cbc8"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:  "56903cbbfdb43b3b8ee734a12704de10ed8d66921befb8a39e479523eeccc47e"
    sha256 cellar: :any_skip_relocation, monterey:       "d4b08a5d3191a3719528da64cf66159d180fdd34d8e502e3023409668745f35f"
    sha256 cellar: :any_skip_relocation, big_sur:        "88e21c2c7a02dd15351fe61cce93e621f8c0b1c62eb4163cfcd539586af92ba8"
    sha256 cellar: :any_skip_relocation, catalina:       "e886c545086c1ad13e4e2f8ae7d9c418fa68cea837fb882a46cfcb25e0d4c918"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "4cdfaaf5224e8aad43047466eb462677e40a9b85e2e38801e56532ad31e6880b"
  end

  depends_on "cmake" => :build

  uses_from_macos "libxml2"
  uses_from_macos "ncurses"
  uses_from_macos "python", since: :catalina
  uses_from_macos "zlib"

  on_linux do
    keg_only "it conflicts with llvm"
  end

  def install
    llvmpath = if build.head?
      ln_s buildpath/"clang", buildpath/"llvm/tools/clang"

      buildpath/"llvm"
    else
      resource("clang").stage do |r|
        (buildpath/"llvm-#{version}.src/tools/clang").install Pathname("clang-#{r.version}.src").children
      end

      buildpath/"llvm-#{version}.src"
    end

    system "cmake", "-S", llvmpath, "-B", "build",
                    "-DLLVM_EXTERNAL_PROJECTS=clang",
                    "-DLLVM_INCLUDE_BENCHMARKS=OFF",
                    *std_cmake_args
    system "cmake", "--build", "build", "--target", "clang-format"

    git_clang_format = llvmpath/"tools/clang/tools/clang-format/git-clang-format"
    inreplace git_clang_format, %r{^#!/usr/bin/env python$}, "#!/usr/bin/env python3"

    bin.install "build/bin/clang-format", git_clang_format
    (share/"clang").install llvmpath.glob("tools/clang/tools/clang-format/clang-format*")
  end

  test do
    system "git", "init"
    system "git", "commit", "--allow-empty", "-m", "initial commit", "--quiet"

    # NB: below C code is messily formatted on purpose.
    (testpath/"test.c").write <<~EOS
      int         main(char *args) { \n   \t printf("hello"); }
    EOS
    system "git", "add", "test.c"

    assert_equal "int main(char *args) { printf(\"hello\"); }\n",
        shell_output("#{bin}/clang-format -style=Google test.c")

    ENV.prepend_path "PATH", bin
    assert_match "test.c", shell_output("git clang-format")
  end
end
