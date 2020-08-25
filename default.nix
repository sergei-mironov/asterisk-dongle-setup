{ pkgs ? import <nixpkgs> {}
, stdenv ? pkgs.stdenv
}:

let
  local = rec {
    callPackage = pkgs.lib.callPackageWith collection;

    collection = rec {

      asterisk = pkgs.asterisk_15.overrideAttrs (old: rec {
        pname = old.pname + "-tweaked";
        configureFlags = old.configureFlags ++ ["--disable-xmldoc"];
      });


      asterisk-chan-dongle = stdenv.mkDerivation {
        name = "asterisk-chan-dongle";

        # src = pkgs.fetchgit {
        #   url = "https://github.com/wdoekes/asterisk-chan-dongle";
        #   rev = "0d1bad55b55940cecc9b196c72e17fc254a3d5a7";
        #   sha256 = "sha256:1nvbc5azqgpc7vwyc0mskqxpnrz8a65a37r6n7nisw3r9q7axasy";
        # };

        src = ./asterisk-chan-dongle;

        preConfigure = ''
          ./bootstrap
        '';

        configureFlags = [
          "--with-astversion=${asterisk.version}"
          "--with-asterisk=${asterisk}/include"
          "--with-iconv=${pkgs.libiconv}/include"
          "--enable-debug"
          "DESTDIR=${placeholder "out"}"
        ];

        buildInputs = [
          asterisk
          pkgs.autoconf
          pkgs.automake
          pkgs.sqlite
          pkgs.libiconv
        ];
      };

      asterisk-modules = pkgs.symlinkJoin {
        name = "asterisk-modules";
        paths = [ "${asterisk}/lib/asterisk/modules"
                  asterisk-chan-dongle ];
      };



      asterisk-conf = stdenv.mkDerivation {
        name = "asterisk-conf";
        buildCommand = ''
          mkdir -pv $out
          mkdir -pv $out/etc/asterisk
          for f in ${asterisk}/etc/asterisk/* ; do
            cp -R $f $out/etc/asterisk
          done

          rm $out/etc/asterisk/asterisk.conf
          cat >$out/etc/asterisk/asterisk.conf <<EOF
          [directories]
          astetcdir => $out/etc/asterisk
          astmoddir => ${asterisk-modules}
          astvarlibdir => ${asterisk}/var/lib/asterisk
          astdbdir => /tmp/asterisk
          astkeydir => ${asterisk}/var/lib/asterisk
          astdatadir => ${asterisk}/var/lib/asterisk
          astagidir => ${asterisk}/var/lib/asterisk/agi-bin
          astspooldir => /tmp/asterisk
          astrundir => /tmp/asterisk/
          astlogdir => /tmp/asterisk/
          astsbindir => ${asterisk}/sbin

          [options]
          verbose = 255
          debug = 255
          runuser = root		; The user to run as.
          rungroup = root		; The group to run as.
          EOF

          # cp -v ${asterisk-chan-dongle.src}/etc/dongle.conf $out/etc/asterisk
          cat >$out/etc/asterisk/dongle.conf <<EOF
          [general]
          interval=15
          smsdb=/tmp/asterisk/smsdb
          csmsttl=600

          [dongle0]
          data=/dev/ttyUSB0		; tty port for AT commands; 		no default value
          audio=/dev/ttyUSB1		; tty port for audio connection; 	no default value

          ; or you can omit both audio and data together and use imei=123456789012345 and/or imsi=123456789012345
          ;  imei and imsi must contain exactly 15 digits !
          ;  imei/imsi discovery is available on Linux only
          imei=123456789012345
          imsi=123456789012345
          EOF
        '';
      };

    };
  };

in
  local.collection
