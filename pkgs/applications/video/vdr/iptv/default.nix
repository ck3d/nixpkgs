{ stdenv, fetchurl, vdr, curl
}: stdenv.mkDerivation rec {

  pname = "vdr-iptv";
  version = "2.4.0";

  src = fetchurl {
    url = "http://www.saunalahti.fi/~rahrenbe/vdr/iptv/files/${pname}-${version}.tgz";
    sha256 = "119iyggldbf22d5x6ayg723f0jza7pvvyni3mmxrmqw7zipipnbk";
  };

  buildInputs = [
    curl
    vdr
  ];

  makeFlags = [ "DESTDIR=$(out)" ];

  meta = with stdenv.lib; {
    homepage = "http://www.saunalahti.fi/~rahrenbe/vdr/iptv/";
    description = "This is an IPTV plugin for the Video Disk Recorder (VDR).";
    maintainers = [ maintainers.ck3d ];
    license = licenses.gpl2;
    platforms = [ "i686-linux" "x86_64-linux" ];
  };

}
