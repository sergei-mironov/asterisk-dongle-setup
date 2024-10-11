{ pkgs ? import <nixpkgs> {}
, asterisk-chan-dongle
, secrets
, revision ? null
, stdenv ? pkgs.stdenv
}:

let
  asterisk-chan-dongle-src = asterisk-chan-dongle;

  inherit (secrets) telegram_master_nicname dongle_device_data
  dongle_device_audio telegram_session dongleman_spool incoming_call_handler;

  python = pkgs.python3Packages;

  local = rec {
    callPackage = pkgs.lib.callPackageWith collection;

    collection = rec {

      inherit pkgs;
      inherit (pkgs) sox yate;

      mypyps = pp: let
        pyls = pp.python-lsp-server.override { };
        pyls-mypy = pp.pylsp-mypy.override { python-lsp-server=pyls; };
        in with pp; [
        pandas
        requests
        pyst2
        ipython
        telethon
        ari-py
        websockets
        pyls
        pyls-mypy
        aiohttp
      ];

      mypython = pkgs.python3.withPackages mypyps;

      shell = pkgs.mkShell {
        name = "shell";
        buildInputs = [
          pkgs.ccls
          mypython
          pkgs.gdb
        ];
      shellHook = with pkgs; ''
        export PYTHONPATH=`pwd`/python:$PYTHONPATH
      '';
      };

      # FIXME: Remove boilerplate
      # FIXME: Here all the secrets go to the /nix/store :(
      python_secrets_json = pkgs.writeText "python_secrets.json"
        (with secrets; ''
        { "telegram_app_title":"${telegram_app_title}"
        , "telegram_api_id":${toString telegram_api_id}
        , "telegram_api_hash":"${telegram_api_hash}"
        , "telegram_bot_token":"${telegram_bot_token}"
        , "telegram_master_nicname":"${telegram_master_nicname}"
        , "telegram_phone":"${telegram_phone}"
        , "telegram_chat_id":${toString telegram_chat_id}
        , "asterisk_ari_user":"${asterisk_ari_user}"
        , "asterisk_ari_password":"${asterisk_ari_password}"
        , "asterisk_ari_app":"${asterisk_ari_app}"
        , "asterisk_bind_ip":"${asterisk_bind_ip}"
        }'');

      # FIXME: Toxic binary component! Get rid of it ASAP!
      codec_opus = stdenv.mkDerivation rec {
        name = "codec_opus";

        src = pkgs.fetchurl {
          url = "http://downloads.digium.com/pub/telephony/codec_opus/asterisk-16.0/x86-64/codec_opus-16.0_1.3.0-x86_64.tar.gz";
          sha256 = "sha256:1axsrlr1a0ki4gvxqbh2cmnzgkvyvpgqxpg82hlq2gr0ilnp1c3a";
        };

        installPhase = ''
          mkdir -pv $out/lib/asterisk/modules
          cp -v -r -t $out/lib/asterisk/modules *so
        '';
      };

      asterisk16 = pkgs.asterisk_16.overrideAttrs (old: rec {
        pname = old.pname + "+opus";

        configureFlags = old.configureFlags ++ [
          "--disable-xmldoc"
        ];

        buildInputs = old.buildInputs ++ [ pkgs.libopus.dev ];
      });
      asterisk = pkgs.asterisk_20;

      usb_modeswitch = stdenv.mkDerivation {
        name = "usb_modeswitch";

        buildInputs = with pkgs; [libusb.dev pkg-config gnumake];

        makeFlags = "DESTDIR=\${out}";

        src = pkgs.fetchurl {
          url = "https://www.draisberghof.de/usb_modeswitch/usb-modeswitch-2.6.0.tar.bz2";
          sha256 = "sha256:18wbbxc5cfsmikba0msdvd5qlaga27b32nhrzicyd9mdddp265f2";
        };
      };

      dongle-monitor = import ./nix/dongle-monitor.nix {
        inherit pkgs stdenv secrets usb_modeswitch; };

      minotaur = python.buildPythonPackage rec {
        pname = "minotaur";
        version = "0.0.3";
        doCheck = false; # Minotaur doesn't have tests
        src = python.fetchPypi {
          inherit pname version;
          sha256 = "sha256:0i9py9rz2165hd3lnpa7h7iv7im5zq2qay5i84dw0q304ykj1z80";
        };
      };

      pyst2 = python.buildPythonPackage rec {
        pname = "pyst2";
        version = "0.5.1";
        propagatedBuildInputs = with python ; [ six ];
        doCheck = false; # due to missing `import SocketServer`
        src = python.fetchPypi {
          inherit pname version;
          sha256 = "sha256:1kw13g7wldzrnnr9vcm97m4c8pv801hl4fl7q88jvz0q9caz9s07";
        };
      };

      swaggerpy = python.buildPythonPackage rec {
        pname = "swaggerpy";
        version = "0.2.1";
        propagatedBuildInputs = with python ; [ requests websocket_client ];
        doCheck = false; # local HTTP requests don't work
        src = python.fetchPypi {
          inherit pname version;
          sha256 = "sha256:07xdmjqwv7rfv5828yc6dk7197w3h2qj2lqbpj0x37pb2wmvqm7s";
        };
        postPatch = ''
          for f in $(find -name '*\.py'); do
            substituteInPlace $f \
              --replace 'from swagger_model' 'from swaggerpy.swagger_model' \
              --replace 'from processors' 'from swaggerpy.processors' \
              --replace 'import urlparse' 'import urllib.parse as urlparse' \
              --replace 'urllib.urlencode' 'urllib.parse.urlencode'
          done
        '';
      };

      ari-py = python.buildPythonPackage rec {
        pname = "ari-py";
        version = "0.1.3";
        propagatedBuildInputs = with python ; [ swaggerpy urllib3 ];
        doCheck = false; # local HTTP requests don't work
        src = pkgs.fetchFromGitHub {
          owner = "asterisk";
          repo = pname;
          # rev = "c182988ec87a9733913dd46a710cceba38fe60e7";
          # sha256 = "sha256:1bmf1pgabr9p54yp1r9n9vlmsyz8y9hwqchr6w1fs6dsix7d4bn6";
          rev = "1647d79176d9ac0dacf4655ca6cb07bd70351f62";
          sha256 = "sha256:0gb5jmnz84pzs2l311pl544410jvq5bdjmb1qnds6kx8r2acjj38";
        };

      postPatch = ''
        for f in $(find -name '*\.py'); do
          substituteInPlace $f \
            --replace 'import urlparse' 'import urllib.parse as urlparse'
        done
      '';
      };

      tdlib_160 = stdenv.mkDerivation rec {
        version = "1.6.0";
        pname = "tdlib";

        src = pkgs.fetchFromGitHub {
          owner = "tdlib";
          repo = "td";
          rev = "v${version}";
          sha256 = "0zlzpl6fgszg18kwycyyyrnkm255dvc6fkq0b0y32m5wvwwl36cv";
        };

        buildInputs = with pkgs; [ gperf openssl readline zlib ];
        nativeBuildInputs = with pkgs; [ cmake ];
      };

      pjsip = pkgs.pjsip.overrideAttrs (old: rec {

        pname = old.pname + "+opus";
        version = "2.9";
        src = pkgs.fetchFromGitHub {
          owner = "pjsip";
          repo = "pjproject";
          rev = version;
          sha256 = "sha256:0q6363dqls6wwhc2pnlzj2iyska9lg0wc2rskkyid4kfn1agfamp";
        };
        buildInputs = old.buildInputs ++ [ pkgs.libopus.dev ];
        configureFlags = [ "--disable-sound" "CFLAGS=-O3" ];
        patches = []; # Disable the AARCH64 patch
        preBuild = ''
          if test -d ${tg2sip.src} ; then
            cp ${tg2sip.src}/buildenv/config_site.h pjlib/include/pj/config_site.h
          else
            mkdir tg2sip-src
            ${pkgs.atool}/bin/aunpack --extract-to=tg2sip-src ${tg2sip.src}
            cp tg2sip-src/tg2sip*/buildenv/config_site.h pjlib/include/pj/config_site.h
          fi
        '';
      });


      tdlib = pkgs.tdlib.overrideAttrs (old: rec {
        version = "1.8.0";
        src = pkgs.fetchFromGitHub {
          owner = "tdlib";
          repo = "td";
          rev = "v${version}";
          sha256 = "19psqpyh9a2kzfdhgqkirpif4x8pzy89phvi59dq155y30a3661q";
        };
      });

      tg2sip = pkgs.gcc9Stdenv.mkDerivation rec {
        name = "tg2sip";
        version = "1.3.0";

        buildInputs = with pkgs; [
          openssl libopus.dev pkgconfig cmake pjsip spdlog_0
          alsaLib tdlib_160 ];

        # dontStrip = true;
        # cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Debug" "-DCMAKE_C_FLAGS=-g"
        #   "-DCMAKE_CXX_FLAGS=-g" "-DVERBOSE=1"];

        patchPhase = ''
          substituteInPlace ./CMakeLists.txt --replace 'Td 1.7.10' 'Td 1.8.0'
        '';

        installPhase = ''
          mkdir -pv $out/bin
          cp -v tg2sip gen_db $out/bin
        '';

        # src = ./tg2sip;
        src = pkgs.fetchurl {
          url = "https://github.com/Infactum/${name}/archive/v${version}.tar.gz";
          sha256 = "sha256:1ql3b4hsdc3hjfzama64bl87mmqv12plbh83jn5s9vgvmk5cp9gh";
        };
      };

      filelock = python.buildPythonPackage rec {
        name = "filelock-${version}";
        version = "2.0.12";

        # buildInputs = with self; [ ];

        src = pkgs.fetchgit {
          url = "https://github.com/benediktschmitt/py-filelock";
          rev = "0de5909050a61c4aba25e89a1c1024cb695ac4cb";
          sha256 = "1m5pv1alh8fk9wc5zbyh397nl0v824zv0whwd7vn5531pcwwksb8";
        };
      };

      python-scripts = python.buildPythonApplication {
        pname = "python-scripts";
        version = "1.0";
        src = ./python;
        pythonPath = with python; [
          filelock telethon minotaur ari-py websockets
        ];
        patchPhase = ''
          for f in $(find -type f -name '*.py'); do
            echo "Patching $f"
            sed -i "s|%DONGLEMAN_SPOOL%|\"${dongleman_spool}\"|g" "$f"
            sed -i "s|%DONGLEMAN_TGSESSION%|\"${telegram_session}\"|g" "$f"
            sed -i "s|%DONGLEMAN_SECRETS%|\"${python_secrets_json}\"|g" "$f"
          done
        '';
        doCheck = false;
      };

      lenny-sound-files = stdenv.mkDerivation {
        name = "lenny-sound-files";
        buildCommand = ''
          mkdir -pv $out
          cp -R ${./app/lenny/sound}/* $out
        '';
        pattern-phrase = "Lenny";
        pattern-bg = "backgroundnoise";
      };

      robot-sound-files = stdenv.mkDerivation {
        name = "robot-sound-files";
        buildCommand = ''
          mkdir -pv $out
          cp -R ${./app/robot2}/backgroundnoise.ulaw \
                ${./app/robot2}/Phrase_*ulaw $out
        '';
        pattern-phrase = "Phrase_";
        pattern-bg = "backgroundnoise";
      };

      sound-files = secrets.sound_files {
        inherit lenny-sound-files robot-sound-files;
      };
      sound-pattern-phrase = files : var : "${files}/${files.pattern-phrase}${var}";
      sound-pattern-bg = files : "${files}/${files.pattern-bg}";

      asterisk-chan-dongle = stdenv.mkDerivation {
        name = "asterisk-chan-dongle";

        # src = pkgs.fetchgit {
        #   url = "https://github.com/wdoekes/asterisk-chan-dongle";
        #   rev = "0d1bad55b55940cecc9b196c72e17fc254a3d5a7";
        #   sha256 = "sha256:1nvbc5azqgpc7vwyc0mskqxpnrz8a65a37r6n7nisw3r9q7axasy";
        # };

        src = asterisk-chan-dongle-src;

        preConfigure = ''
          ./bootstrap
        '';

        configureFlags = [
          "--with-astversion=${asterisk.version}"
          "--with-asterisk=${asterisk}/include"
          "--with-iconv=${pkgs.libiconv}/include"
          "--enable-debug"
          "--enable-apps"
          "--enable-manager"
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
                  asterisk-chan-dongle
                  # "${codec_opus}/lib/asterisk/modules"
                ];
      };

      asterisk-tmp = "/tmp/asterisk";

      handler_sip =
        if incoming_call_handler == "tg2sip" then
          "tg#${telegram_master_nicname}@telegram"
        else if incoming_call_handler == "sip" then
          "softphone"
        else
          throw "`incoming_call_handler` should be either `tg2sip` or `sip`";

      asterisk-conf = stdenv.mkDerivation {
        name = "asterisk-conf";
        buildCommand = with secrets; ''
          mkdir -pv $out
          mkdir -pv $out/etc/asterisk
          for f in ${asterisk}/etc/asterisk/* ; do
            cp -R $f $out/etc/asterisk
          done

          sed -i 's@console => notice,warning,error@console => notice,warning,error,debug@g' $out/etc/asterisk/logger.conf

          rm $out/etc/asterisk/asterisk.conf
          cat >$out/etc/asterisk/asterisk.conf <<EOF
          [directories]
          astetcdir => $out/etc/asterisk
          astmoddir => ${asterisk-modules}
          astvarlibdir => ${asterisk}/var/lib/asterisk
          astdbdir => ${asterisk-tmp}
          astkeydir => ${asterisk}/var/lib/asterisk
          astdatadir => ${asterisk}/var/lib/asterisk
          astagidir => ${asterisk}/var/lib/asterisk/agi-bin
          astspooldir => ${asterisk-tmp}
          astrundir => ${asterisk-tmp}
          astlogdir => ${asterisk-tmp}
          astsbindir => ${asterisk}/sbin

          [options]
          verbose = 9
          debug = 0
          runuser = root		; The user to run as.
          rungroup = root		; The group to run as.
          EOF

          ###################
          ## CODECS.CONF
          ###################
          chmod +w $out/etc/asterisk/codecs.conf
          cat >>$out/etc/asterisk/codecs.conf <<EOF
          [opus]
          type=opus
          fec=yes
          dtx=yes
          cbr=yes
          bitrate=48000
          complexity=8
          max_playback_rate=48000
          application=audio
          signal=voice
          EOF


          ###################
          ## MODULES.CONF
          ###################

          rm $out/etc/asterisk/modules.conf
          cat >$out/etc/asterisk/modules.conf <<EOF
          [modules]
          autoload=yes
          noload => chan_alsa.so
          noload => chan_console.so
          noload => res_hep.so
          noload => res_hep_pjsip.so
          noload => res_hep_rtcp.so
          EOF

          ###################
          ## DONGLE.CONF
          ###################

          # cp -v ${asterisk-chan-dongle.src}/etc/dongle.conf $out/etc/asterisk
          cat >$out/etc/asterisk/dongle.conf <<EOF
          [general]
          interval=15
          ;smsdb=/tmp/asterisk/smsdb
          ;csmsttl=5
          jbenable = yes
          jbforce = yes
          jbmaxsize = 200

          [defaults]
          group=0				; calling group
          rxgain=0			; increase the incoming volume; may be negative
          txgain=0			; increase the outgoint volume; may be negative
          autodeletesms=yes		; auto delete incoming sms
          resetdongle=yes			; reset dongle during initialization with ATZ command
          u2diag=-1			; set ^U2DIAG parameter on device (0 = disable everything except modem function) ; -1 not use ^U2DIAG command
          usecallingpres=yes		; use the caller ID presentation or not
          callingpres=allowed_passed_screen ; set caller ID presentation		by default use default network settings
          disablesms=no			; disable of SMS reading from device when received
                            ;  chan_dongle has currently a bug with SMS reception. When a SMS gets in during a
                            ;  call chan_dongle might crash. Enable this option to disable sms reception.
                            ;  default = no

          language=en			; set channel default language
          mindtmfgap=45			; minimal interval from end of previews DTMF from begining of next in ms
          mindtmfduration=80		; minimal DTMF tone duration in ms
          mindtmfinterval=200		; minimal interval between ends of DTMF of same digits in ms

          callwaiting=auto		; if 'yes' allow incoming calls waiting; by default use network settings
                              ; if 'no' waiting calls just ignored
          disable=no			; OBSOLETED by initstate: if 'yes' no load this device and just ignore this section

          initstate=start	; specified initial state of device, must be one of 'stop' 'start' 'remote'
                          ;   'remove' same as 'disable=yes'

          exten=voice		  ; exten for start incoming calls, only in case of Subscriber Number not available!, also set to CALLERID(ndid)

          dtmf=relax			; control of incoming DTMF detection, possible values:
                          ;   off	   - off DTMF tones detection, voice data passed to asterisk unaltered
                          ;              use this value for gateways or if not use DTMF for AVR or inside dialplan
                          ;   inband - do DTMF tones detection
                          ;   relax  - like inband but with relaxdtmf option
                          ;  default is 'relax' by compatibility reason

          [dongle0]
          data=${dongle_device_data}
          audio=${dongle_device_audio}
          context=dongle-incoming-tg
          language=ru
          smsaspdu=yes
          EOF

          ###################
          ## EXTENSIONS.CONF
          ###################

          rm $out/etc/asterisk/extensions.conf
          cat >$out/etc/asterisk/extensions.conf <<"EOF"
          [general]

          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
          ; This section specifies a voicecall handler which does the following:
          ; 1) Dial the Telegram 2) If answered, establish the channel 3) If not
          ; answered, enable Lenny-like robot 4) In any case, record the
          ; conversation a send the recording to the Telegram

          [dongle-incoming-tg]
          exten => sms,1,Verbose(SMS-IN ''${CALLERID(num)} ''${SMS_BASE64})
          same => n,Set(MSG=--message-base64=''${SMS_BASE64})
          same => n,Hangup()

          exten => voice,1,Answer()
          same => n,MixMonitor(wav,''${UNIQUEID},m)
          same => n,Set(VOICE=--attach-voice="${asterisk-tmp}/monitor/''${UNIQUEID}.wav")
          same => n,Set(JITTERBUFFER(adaptive)=default)
          same => n,Verbose(Inbound parameters set)
          same => n,System(${python-scripts}/bin/dongleman_send.py ''${EPOCH} ''${DONGLENAME} --from-name=''${CALLERID(num)} --message='Incoming voice call')
          same => n,Dial(PJSIP/${handler_sip},30,b(dongle-incoming-tg^outbound^1))
          same => n,Verbose(DIALSTATUS ''${DIALSTATUS})
          same => n,GotoIf($["''${DIALSTATUS}" = "ANSWER"]?stop)
          same => n,GotoIf($["''${DIALSTATUS}" = "NOANSWER"]?stop)
          same => n,GotoIf($["''${DIALSTATUS}" = "CHANUNAVAIL"]?unavail)
          ; same => n,GotoIf($["''${DIALSTATUS}" = "CHANUNAVAIL"]?dongle-incoming-tg,talk,1)
          same => n(stop),Hangup()
          same => n(unavail),Playtones(congestion)
          same => n,Wait(5)
          same => n,StopPlaytones()
          same => n,Hangup()
          exten => outbound,1,Set(JITTERBUFFER(adaptive)=default)
          same => n,Verbose(Outbound parameters set)
          same => n,Return()
          exten => talk,1,Set(i=''${IF($["0''${i}"="011"]?7:$[0''${i}+1])})
          same => n,Playback(${sound-pattern-phrase sound-files ("$"+"{i}")})
          same => n,BackgroundDetect(${sound-pattern-bg sound-files},1000)
          same => n,Hangup()
          exten => h,1,StopMixMonitor()
          same => n,System(${python-scripts}/bin/dongleman_send.py ''${EPOCH} ''${DONGLENAME} --from-name=''${CALLERID(num)} ''${MSG} ''${VOICE})

          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
          ; This handler puts the incoming call into stasis to be controlled
          ; with dongleman python script.

          [context-sip2gsm]
          exten => 1000,1,NoOp()
          same =>      n,Answer()
          same =>      n,Stasis(${asterisk_ari_app})
          same =>      n,Hangup()

          exten => 1001,1,NoOp()
          same => n,Set(VOICE=--attach-voice="${asterisk-tmp}/monitor/''${UNIQUEID}.wav")
          same => n,Goto(context-sip2gsm,talk,1)
          exten => talk,1,Set(i=''${IF($["0''${i}"="016"]?7:$[0''${i}+1])})
          same => n,Playback(${sound-pattern-phrase lenny-sound-files ("$"+"{i}")})
          same => n,BackgroundDetect(${sound-pattern-bg lenny-sound-files},1000)
          same => n,Hangup()
          EOF

          ###################
          ## PJSIP.CONF
          ###################

          rm $out/etc/asterisk/pjsip.conf
          cat >$out/etc/asterisk/pjsip.conf <<EOF
          [transport-udp]
          type=transport
          protocol=udp
          bind=${asterisk_bind_ip}
          local_net=${tg2sip_bind_ip}/24
          local_net=${softphone_bind_ip}/24
          local_net=127.0.0.1/32
          ; external_media_address=127.0.0.1

          [telegram]
          type=endpoint
          aors=telegram
          transport=transport-udp
          context=context-sip2gsm
          rtp_symmetric=yes
          disallow=all
          allow=opus

          [telegram]
          type=aor
          contact=sip:telegram@${tg2sip_bind_ip}:5062
          ; contact=sip:telegram@192.168.1.36:5062
          ; contact=sip:telegram@192.168.1.36:5063

          [telegram-identify]
          type=identify
          endpoint=telegram
          match=${tg2sip_bind_ip}:5062/255.255.255.255
          ; match=127.0.0.1:5062/255.255.255.255

          [softphone]
          type=endpoint
          transport=transport-udp
          aors=softphone
          auth=softphone-auth
          context=context-sip2gsm
          rtp_symmetric=yes
          disallow=all
          allow=opus

          [softphone]
          type=aor
          max_contacts=5

          [softphone-auth]
          type=auth
          auth_type=userpass
          password=softphone
          username=softphone

          EOF

          ###################
          ## SIP.CONF
          ###################

          rm $out/etc/asterisk/sip.conf
          cat >$out/etc/asterisk/sip.conf <<EOF
          [general]
          enabled = false;
          websocket_enabled = false;
          EOF

          ###################
          ## HTTP.CONF
          ###################

          rm $out/etc/asterisk/http.conf
          cat >$out/etc/asterisk/http.conf <<EOF
          [general]
          enabled = yes
          bindaddr = ${asterisk_bind_ip}
          EOF

          ###################
          ## RTP.CONF
          ###################

          # rm $out/etc/asterisk/rtp.conf
          # cat >$out/etc/asterisk/rtp.conf <<EOF
          # [general]
          # rtpstart=10000
          # rtpend=20000
          # ice_acl = named_acl
          # ice_deny = 0.0.0.0/0
          # ice_permit = 127.0.0.1/32
          # EOF

          ###################
          ## ARI.CONF
          ###################

          rm $out/etc/asterisk/ari.conf
          cat >$out/etc/asterisk/ari.conf <<EOF
          [general]
          enabled = yes
          pretty = yes
          allowed_origins = *

          [${asterisk_ari_user}]
          type = user
          read_only = no
          password = ${asterisk_ari_password}
          EOF
        '';
      };

      tg2sip-conf = pkgs.writeTextDir "etc/settings.ini"
        (with secrets; ''
        [logging]
        core=3                 ; 0-trace  2-info  4-err   6-off
                               ; 1-debug  3-warn  5-crit

        tgvoip=5               ; same as core
        pjsip=3                ; same as core
        sip_messages=true      ; log sip messages if pjsip debug is enabled

        console_min_level=0    ; minimal log level that will be written into console
        file_min_level=0       ; same but into file

        ;tdlib=3                ; TDLib is written to file only and has its own log level values
                                ; not affected by other log settings
                                ; 0-fatal   2-warnings  4-debug
                                ; 1-errors  3-info      5-verbose debug

        [sip]
        public_address=${tg2sip_bind_ip}
        port=5062
        ;port_range=0           ; Specify the port range for socket binding, relative to the start
                                ; port number specified in port.
        id_uri=sip:telegram@${tg2sip_bind_ip}
                                ; The Address of Record or AOR, that is full SIP URL that identifies the account.
                                ; The value can take name address or URL format, and will look something
                                ; like "sip:account@serviceprovider".

        callback_uri=sip:1000@${asterisk_bind_ip}:5060 ; FIXME: unhardcode the port
                                ; SIP URI for TG->SIP incoming calls processing

        raw_pcm=false           ; use L16@48k codec if true or OPUS@48k otherwise
                                ; keep true for lower CPU consumption

        ;thread_count=1         ; Specify the number of worker threads to handle incoming RTP
                                ; packets. A value of one is recommended for most applications.

        [telegram]
        api_id=${toString tg2sip_api_id}
        api_hash=${tg2sip_api_hash}
        system_language_code=ru-RU     ; IETF language tag of the user's operating system language

        [other]
        extra_wait_time=10             ; If gateway gets temporary blocked with "Too Many Requests" reason,
                                       ; then block all outgoing telegram requests for X more seconds than was
                                       ; requested by server
        ;peer_flood_time=86400         ; Seconds to wait on PEER_FLOOD
      '');
    };
  };

in
  local.collection
