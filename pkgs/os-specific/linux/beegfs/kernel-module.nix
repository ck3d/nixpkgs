{ stdenv, fetchurl, bash, which, coreutils,
  kmod, kernel
} :

let
  version = "6.17";
in stdenv.mkDerivation { 
  name = "beegfs-module-${version}-${kernel.version}";

  src = fetchurl {
    url = "https://git.beegfs.com/pub/v6/repository/archive.tar.bz2?ref=${version}";
    sha256 = "10xs7gzdmlg23k6zn1b7jij3lljn7rr1j6h476hq4lbg981qk3n3";
  };

  hardeningDisable = [ "fortify" "pic" "stackprotector" ];

  nativeBuildInputs = [ which bash coreutils kmod ];
  postPatch = ''
    find -type f -executable -exec sed -i "s:/bin/bash:${bash}/bin/bash:" \{} \;
    find -type f -name Makefile -exec sed -i "s:/bin/bash:${bash}/bin/bash:" \{} \;
    find -type f -name Makefile -exec sed -i "s:/bin/true:${coreutils}/bin/true:" \{} \;
    find -type f -name "*.mk" -exec sed -i "s:/bin/true:${coreutils}/bin/true:" \{} \;
  '';


  buildPhase = ''
    cd beegfs_client_module/build
    export KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/
    make 
  '';

  installPhase = ''
    instdir=$out/lib/modules/${kernel.modDirVersion}/extras/fs/beegfs
    mkdir -p $instdir
    cp beegfs.ko $instdir
  '';

  meta = with stdenv.lib; {
    description = "High performance distributed filesystem";
    homepage = "https://www.beegfs.io";
    platforms = [ "i686-linux" "x86_64-linux" ];
    license = licenses.gpl2;
    maintainters = with maintainers; [ markuskowa ];
  };
}


