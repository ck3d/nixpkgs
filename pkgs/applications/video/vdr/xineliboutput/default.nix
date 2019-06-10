{ stdenv, fetchurl, vdr
, libav, libcap, libvdpau
, xineLib, libjpeg, libextractor, mesa_noglu, libGLU
, libX11, libXext, libXrender, libXrandr
}: stdenv.mkDerivation rec {
  name = "vdr-xineliboutput-2.1.0";
  src = fetchurl {
    name = "src.tgz";
    url = "https://sourceforge.net/projects/xineliboutput/files/xineliboutput/${name}/${name}.tgz/download";
    sha256 = "6af99450ad0792bd646c6f4058f6e49541aab8ba3a10e131f82752f4d5ed19de";
  };

  configurePhase = ''
    ./configure
    sed -i config.mak \
      -e 's,XINEPLUGINDIR=/[^/]*/[^/]*/[^/]*/,XINEPLUGINDIR=/,'
  '';

  makeFlags = [
    "DESTDIR=$(out)"
  ];

  buildInputs = [
    libav
    libcap
    libextractor
    libjpeg
    libGLU
    libvdpau
    libXext
    libXrandr
    libXrender
    libX11
    mesa_noglu
    vdr
    xineLib
  ];
}
