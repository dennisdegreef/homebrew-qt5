class OracleHomeVarRequirement < Requirement
  fatal true
  satisfy(:build_env => false) { ENV["ORACLE_HOME"] }

  def message; <<-EOS.undent
      To use --with-oci you have to set the ORACLE_HOME environment variable.
      Check Oracle Instant Client documentation for more information.
    EOS
  end
end

class Qt5 < Formula
  desc "Version 5 of the Qt framework"
  homepage "https://www.qt.io/"
  url "https://download.qt.io/official_releases/qt/5.4/5.4.2/single/qt-everywhere-opensource-src-5.4.2.tar.xz"
  mirror "https://www.mirrorservice.org/sites/download.qt-project.org/official_releases/qt/5.4/5.4.2/single/qt-everywhere-opensource-src-5.4.2.tar.xz"
  sha256 "8c6d070613b721452f8cffdea6bddc82ce4f32f96703e3af02abb91a59f1ea25"

  bottle do
    root_url "https://link0.net/homebrew"
    sha256 "787951f01c02c39065f65ad63d203dd003bbd1f54c20daf4dff898781331ceaf" => :mavericks
  end

#  bottle do
#    sha256 "1d3aee1664b44e912ddd307fc7f1eff25e835452ce44705acaa4162f79006ef7" => :yosemite
#    sha256 "f32d4dde1b09d619e5046b9e5717ab48d7dc6b066b09bbde8d44f74b2ef040fb" => :mavericks
#    sha256 "855e075b522199c52876f44fe2d2a63e4c4b4f9bfd5c6edb0e3dc850fd02ef34" => :mountain_lion
#  end

  head "https://code.qt.io/qt/qt5.git", :branch => "5.4", :shallow => false

  keg_only "Qt 5 conflicts Qt 4 (which is currently much more widely used)."

  option :universal
  option "with-docs", "Build documentation"
  option "with-examples", "Build examples"
  option "with-developer", "Build and link with developer options"
  option "with-oci", "Build with Oracle OCI plugin"

  option "without-webengine", "Build without QtWebEngine module"

  deprecated_option "developer" => "with-developer"
  deprecated_option "qtdbus" => "with-d-bus"

  # Snow Leopard is untested and support has been removed in 5.4
  # https://qt.gitorious.org/qt/qtbase/commit/5be81925d7be19dd0f1022c3cfaa9c88624b1f08
  depends_on :macos => :lion
  depends_on "pkg-config" => :build
  depends_on "d-bus" => :optional
  depends_on :mysql => :optional
  depends_on :xcode => :build

  # There needs to be an OpenSSL dep here ideally, but qt keeps ignoring it.
  # Keep nagging upstream for a fix to this problem, and revision when possible.
  # https://github.com/Homebrew/homebrew/pull/34929
  # https://bugreports.qt.io/browse/QTBUG-42161
  # https://bugreports.qt.io/browse/QTBUG-43456

  depends_on OracleHomeVarRequirement if build.with? "oci"

  def install
    ENV.universal_binary if build.universal?

    args = ["-prefix", prefix,
            "-system-zlib",
            "-qt-libpng", "-qt-libjpeg",
            "-confirm-license", "-opensource",
            "-nomake", "tests", "-release"]

    args << "-nomake" << "examples" if build.without? "examples"

    # never build with qtwebengine
    args << "-skip" << "qtwebengine"

    args << "-plugin-sql-mysql" if build.with? "mysql"

    if build.with? "d-bus"
      dbus_opt = Formula["d-bus"].opt_prefix
      args << "-I#{dbus_opt}/lib/dbus-1.0/include"
      args << "-I#{dbus_opt}/include/dbus-1.0"
      args << "-L#{dbus_opt}/lib"
      args << "-ldbus-1"
      args << "-dbus-linked"
    end

    if MacOS.prefer_64_bit? || build.universal?
      args << "-arch" << "x86_64"
    end

    if !MacOS.prefer_64_bit? || build.universal?
      args << "-arch" << "x86"
    end

    if build.with? "oci"
      args << "-I#{ENV["ORACLE_HOME"]}/sdk/include"
      args << "-L#{ENV["ORACLE_HOME"]}"
      args << "-plugin-sql-oci"
    end

    args << "-developer-build" if build.with? "developer"

    system "./configure", *args
    system "make"
    ENV.j1
    system "make", "install"

    if build.with? "docs"
      system "make", "docs"
      system "make", "install_docs"
    end

    # Some config scripts will only find Qt in a "Frameworks" folder
    frameworks.install_symlink Dir["#{lib}/*.framework"]

    # The pkg-config files installed suggest that headers can be found in the
    # `include` directory. Make this so by creating symlinks from `include` to
    # the Frameworks' Headers folders.
    Pathname.glob("#{lib}/*.framework/Headers") do |path|
      include.install_symlink path => path.parent.basename(".framework")
    end

    # configure saved PKG_CONFIG_LIBDIR set up by superenv; remove it
    # see: https://github.com/Homebrew/homebrew/issues/27184
    inreplace prefix/"mkspecs/qconfig.pri", /\n\n# pkgconfig/, ""
    inreplace prefix/"mkspecs/qconfig.pri", /\nPKG_CONFIG_.*=.*$/, ""

    Pathname.glob("#{bin}/*.app") { |app| mv app, prefix }
  end

  test do
    system "#{bin}/qmake", "-project"
  end

  def caveats; <<-EOS.undent
    We agreed to the Qt opensource license for you.
    If this is unacceptable you should uninstall.
    EOS
  end

  patch do
    url "https://link0.net/qt5.patch"
    sha256 "a0278afefc5e4e950cd2e7403e5c5bd229efadcd52a7f564940573d00bcb0ed2"
  end
  
  # Build error: Fix build with clang 3.7.
  # https://codereview.qt-project.org/#/c/121545/
  # Should land in the 5.5.1 release.
  patch do
    url "https://raw.githubusercontent.com/DomT4/scripts/2107043e8/Homebrew_Resources/Qt5/qt5_el_capitan.diff"
    sha256 "bd8fd054247ec730f60778e210d58cba613265e5df04ec93f4110421fb03b14a"
  end

  # Build error: Fix library paths with Xcode 7 for QtWebEngine.
  # https://codereview.qt-project.org/#/c/122729/
  patch do
    url "https://raw.githubusercontent.com/Homebrew/patches/2fcc1f8ec1df1c90785f4fa6632cebac68772fa9/qt5/el-capitan-2.diff"
    sha256 "b8f04efd047eeed7cfd15b029ece20b5fe3c0960b74f7a5cb98bd36475463227"
  end

  # Build error: Fix CGEventCreateMouseEvent use with 10.11 SDK.
  # https://codereview.qt-project.org/#/c/115138/
  # Should land in the 5.5.1 release.
  patch do
    url "https://gist.githubusercontent.com/UniqMartin/baf089e326f572150971/raw/1de52d53929bc3472cc7f345c16f068c37c75263/qtbug-47641.patch"
    sha256 "c74c73b2d540788f0be2f1f137d0844feca8f5022a044851366380bf2972ead0"
  end
end
