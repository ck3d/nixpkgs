{ stdenv, lib, fetchFromGitHub, kernel, kmod, perl, patchutils, perlPackages }:
let

  media = fetchFromGitHub rec {
    name = repo;
    owner = "tbsdtv";
    repo = "linux_media";
    rev = "91b94c9ed5293cd54b03137d7e0038cf998aca6f"; # 2021-09-27
    sha256 = "sha256-6bugR8d+Plhr/SqcYYa7Ilarr2zZ35SKTTS+HiANa3I=";
  };

  build = fetchFromGitHub rec {
    name = repo;
    owner = "tbsdtv";
    repo = "media_build";
    rev = "c6194cd34ce43f396378b49d256b5e7f339006c6"; # 2021-10-07
    sha256 = "sha256-0rt76Xoj3rV8EYJ9olulr+Kxg6xGYmgGlr+XPayK988=";
  };

in stdenv.mkDerivation {
  pname = "tbs";
  version = "2021.10.07-${kernel.version}";

  srcs = [ media build ];
  sourceRoot = build.name;

  # https://github.com/tbsdtv/linux_media/wiki
  preConfigure = ''
    make dir DIR=../${media.name}
  '';

  postPatch = ''
    patchShebangs .

    sed -i v4l/Makefile \
      -i v4l/scripts/make_makefile.pl \
      -e 's,/sbin/depmod,${kmod}/bin/depmod,g' \
      -e 's,/sbin/lsmod,${kmod}/bin/lsmod,g'

    sed -i v4l/Makefile \
      -e 's,^OUTDIR ?= /lib/modules,OUTDIR ?= ${kernel.dev}/lib/modules,' \
      -e 's,^SRCDIR ?= /lib/modules,SRCDIR ?= ${kernel.dev}/lib/modules,'
  '';

  buildFlags = [ "VER=${kernel.modDirVersion}" ];
  installFlags = [ "DESTDIR=$(out)" ];

  hardeningDisable = [ "all" ];

  nativeBuildInputs = [ patchutils kmod perl perlPackages.ProcProcessTable ]
  ++ kernel.moduleBuildDependencies;

   postInstall = ''
    find $out/lib/modules/${kernel.modDirVersion} -name "*.ko" -exec xz {} \;
  '';

  meta = with lib; {
    homepage = "https://www.tbsdtv.com/";
    description = "Linux driver for TBSDTV cards";
    license = licenses.gpl2;
    maintainers = with maintainers; [ ck3d ];
    priority = -1;
  };
}
