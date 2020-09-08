{ stdenv, fetchFromGitHub, fetchpatch }:
stdenv.mkDerivation rec {
  pname = "redo-c";
  version = "0.2";

  src = fetchFromGitHub {
    owner = "leahneukirchen";
    repo = pname;
    rev = "v${version}";
    sha256 = "11wc2sgw1ssdm83cjdc6ndnp1bv5mzhbw7njw47mk7ri1ic1x51b";
  };

  patches = [
    # Fix non implicit job lease detection. Remove with the next release.
    (fetchpatch {
      url = "https://github.com/leahneukirchen/redo-c/commit/3a3f0056f357b4fa2b9f725725806d370395ff39.patch";
      sha256 = "039hnlwr9gmngsfjvc5fz3zclq32656j8g0njsvl9r3bfxq3ydj5";
    })
  ];

  postPatch = ''
    cp '${./Makefile}' Makefile
  '';

  meta = with stdenv.lib; {
    description = "An implementation of the redo build system in portable C with zero dependencies";
    homepage = "https://github.com/leahneukirchen/redo-c";
    license = licenses.cc0;
    platforms = platforms.all;
    maintainers = with maintainers; [ ck3d ];
  };
}
