{ pkgs ? import <nixpkgs> {}
, stdenv ? pkgs.stdenv
, telegram_session ? throw "telegram_session argument is required"
, telegram_secret ? throw "telegram_secret argument is required"
}:

let
  python = pkgs.python37Packages;

  local = rec {
    callPackage = pkgs.lib.callPackageWith collection;

    collection = rec {

      inherit pkgs;
      inherit (pkgs) sox yate;

      mypyps = ppkgs: with ppkgs; [
        pandas
        requests
        pyst2
        ipython
        telethon
      ];

      mypython = pkgs.python37.withPackages mypyps;

      shell = pkgs.mkShell {
        name = "shell";
        buildInputs = [
          pkgs.ccls
          mypython
        ];
      shellHook = with pkgs; ''
        export PYTHONPATH=`pwd`/python:$PYTHONPATH
      '';
      };

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

      asterisk = pkgs.asterisk_16.overrideAttrs (old: rec {
        pname = old.pname + "-tweaked";

        configureFlags = old.configureFlags ++ [
          "--disable-xmldoc"
        ];
        # postInstall = old.postInstall + ''
        #   cp ${codec_opus}/lib/* $out/lib64/asterisk/modules
        # '';
      });

      usb_modeswitch = stdenv.mkDerivation {
        name = "usb_modeswitch";

        buildInputs = with pkgs; [libusb.dev pkgconfig gnumake];

        makeFlags = "DESTDIR=\${out}";

        src = pkgs.fetchurl {
          url = "https://www.draisberghof.de/usb_modeswitch/usb-modeswitch-2.6.0.tar.bz2";
          sha256 = "sha256:18wbbxc5cfsmikba0msdvd5qlaga27b32nhrzicyd9mdddp265f2";
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

      tg2sip = stdenv.mkDerivation rec {
        name = "tg2sip";
        version = "1.2.0";

        buildInputs = with pkgs; [
          openssl libopus.dev pkgconfig cmake pjsip spdlog_0 tdlib_160
          alsaLib
        ];

        # makeFlags = ["-j30"];

        installPhase = ''
          mkdir -pv $out/bin
          cp -v tg2sip gen_db $out/bin
        '';

        src = pkgs.fetchurl {
          url = "https://github.com/Infactum/${name}/archive/v${version}.tar.gz";
          sha256 = "sha256:0j7bmgzk6aic4kzqs46s4azjmg1vgykvw5vjncsy6s5z2fdp8iia";
        };
      };

      python-scripts = python.buildPythonApplication {
        pname = "python-scripts";
        version = "1.0";
        src = ./python;
        pythonPath = with pkgs.python37Packages; [
          telethon
        ];
        doCheck = false;
      };

      lenny-sound-files = stdenv.mkDerivation {
        name = "lenny-sound-files";
        buildCommand = ''
          mkdir -pv $out
          cp -R ${./app/lenny/sound}/* $out
        '';
      };

      sound-files = lenny-sound-files;

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
                  "${codec_opus}/lib/asterisk/modules" ];
      };



      asterisk-tmp = "/tmp/asterisk";

      asterisk-conf = stdenv.mkDerivation {
        name = "asterisk-conf";
        buildCommand = ''
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
          packet_loss=10
          dtx=yes
          cbr=yes
          bitrate=48000
          complexity=8
          max_playback_rate=48000
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

          noload = chan_pjsip.so
          ; noload = res_pjsip_endpoint_identifier_anonymous.so
          ; noload = res_pjsip_messaging.so
          ; noload = res_pjsip_pidf.so
          noload = res_pjsip_session.so
          ; noload = func_pjsip_endpoint.so
          ; noload = res_pjsip_endpoint_identifier_ip.so
          ; noload = res_pjsip_mwi.so
          ; noload = res_pjsip_pubsub.so
          noload = res_pjsip.so
          ; noload = res_pjsip_acl.so
          ; noload = res_pjsip_endpoint_identifier_user.so
          ; noload = res_pjsip_nat.so
          ; noload = res_pjsip_refer.so
          ; noload = res_pjsip_t38.so
          ; noload = res_pjsip_authenticator_digest.so
          ; noload = res_pjsip_exten_state.so
          ; noload = res_pjsip_notify.so
          ; noload = res_pjsip_registrar_expire.so
          ; noload = res_pjsip_transport_websocket.so
          ; noload = res_pjsip_caller_id.so
          ; noload = res_pjsip_header_funcs.so
          ; noload = res_pjsip_one_touch_record_info.so
          ; noload = res_pjsip_registrar.so
          ; noload = res_pjsip_diversion.so
          ; noload = res_pjsip_log_forwarder.so
          ; noload = res_pjsip_outbound_authenticator_digest.so
          ; noload = res_pjsip_rfc3326.so
          ; noload = res_pjsip_dtmf_info.so
          ; noload = res_pjsip_logger.so
          ; noload = res_pjsip_outbound_registration.so
          ; noload = res_pjsip_sdp_rtp.so
          ; noload = res_pjsip_outbound_publish.so
          ; noload = res_pjsip_config_wizard.so
          ; noload = res_pjproject.so
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
          data=/dev/ttyUSB0
          audio=/dev/ttyUSB1
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

          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

          [dongle-incoming-lenny]
          exten => sms,1,Verbose(SMS-IN ''${CALLERID(num)} ''${SMS_BASE64})
          same => n,Set(MSG=--message-base64=''${SMS_BASE64})
          same => n,Hangup()

          exten => voice,1,Answer()
          same => n,Monitor(wav,''${UNIQUEID},m)
          same => n,Set(VOICE=--attach-voice="${asterisk-tmp}/monitor/''${UNIQUEID}.wav")
          same => n,Goto(dongle-incoming-lenny,talk,1)

          exten => talk,1,Set(i=''${IF($["0''${i}"="016"]?7:$[0''${i}+1])})
          same => n,Playback(${lenny-sound-files}/Lenny''${i})
          same => n,BackgroundDetect(${lenny-sound-files}/backgroundnoise,1000)

          exten => h,1,StopMonitor()
          same => n,System(${python-scripts}/bin/telegram_send.py "${telegram_session}" "${telegram_secret}" ''${EPOCH} ''${DONGLENAME} --from-name=''${CALLERID(num)} ''${MSG} ''${VOICE})

          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

          [dongle-incoming-alice]
          exten => sms,1,Verbose(SMS-IN ''${CALLERID(num)} ''${SMS_BASE64})
          same => n,Set(MSG=--message-base64=''${SMS_BASE64})
          same => n,Hangup()

          exten => voice,1,Answer()
          same => n,Dial(PJSIP/alice-softphone)
          same => n,Hangup()

          exten => h,1,StopMonitor()
          same => n,System(${python-scripts}/bin/telegram_send.py "${telegram_session}" "${telegram_secret}" ''${EPOCH} ''${DONGLENAME} --from-name=''${CALLERID(num)} ''${MSG} ''${VOICE})

          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

          [dongle-incoming-tg]
          exten => sms,1,Verbose(SMS-IN ''${CALLERID(num)} ''${SMS_BASE64})
          same => n,Set(MSG=--message-base64=''${SMS_BASE64})
          same => n,Hangup()

          exten => voice,1,Answer()
          same => n,Dial(SIP/tg#XXXXX@telegram-endpoint) ; TODO fix the nicname
          same => n,Hangup()

          exten => h,1,StopMonitor()
          same => n,System(${python-scripts}/bin/telegram_send.py "${telegram_session}" "${telegram_secret}" ''${EPOCH} ''${DONGLENAME} --from-name=''${CALLERID(num)} ''${MSG} ''${VOICE})

          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

          [telegram-incoming-test]
          exten => sms,1,Verbose(Incoming from telegram)
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
          bind=127.0.0.1

          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

          [alice-softphone]
          type=endpoint
          context=pjsip-incoming
          disallow=all
          allow=ulaw
          auth=alice-auth
          aors=alice-softphone

          [alice-auth]
          type=auth
          auth_type=userpass
          username=alice-softphone
          password=Secret123

          [alice-softphone]
          type=aor
          max_contacts=1

          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

          [telegram-endpoint]
          type=endpoint
          context=telegram-incoming-test
          disallow=all
          allow=opus
          auth=telegram-auth
          aors=telegram-aors

          [telegram-auth]
          type=auth
          auth_type=userpass
          username=telegram  ; Is it for inbound or outbound registrations?
          password=123

          [telegram-aors]
          type=aor
          contact=sip:telegram@127.0.0.1:5062
          EOF


          ###################
          ## SIP.CONF
          ###################
          rm $out/etc/asterisk/sip.conf
          cat >$out/etc/asterisk/sip.conf <<"EOF"
          [general]
          udpbindaddr=0.0.0.0
          ; register => sip:telegram@127.0.0.1:5062
          [telegram-endpoint]
          ; deny=0.0.0.0/0.0.0.0
          type=peer
          ; qualify=yes
          ; permit=192.168.0.2/255.255.0.0
          host=127.0.0.1
          port=5062
          fromdomain=127.0.0.1
          nat=no
          insecure=port,invite
          canreinvite=no
          dtmfmode=rfc2833
          disallow=all
          allow=opus
          context=telegram-incoming-test
          EOF

        '';




      };

      tg2sip-conf = pkgs.writeTextDir "etc/settings.ini" ''
        [logging]
        core=1                 ; 0-trace  2-info  4-err   6-off
                               ; 1-debug  3-warn  5-crit

        tgvoip=5               ; same as core
        pjsip=0                ; same as core
        sip_messages=true      ; log sip messages if pjsip debug is enabled

        console_min_level=0    ; minimal log level that will be written into console
        file_min_level=0       ; same but into file

        ;tdlib=3                ; TDLib is written to file only and has its own log level values
                                ; not affected by other log settings
                                ; 0-fatal   2-warnings  4-debug
                                ; 1-errors  3-info      5-verbose debug

        [sip]
        public_address=127.0.0.1
        port=5062
        ;port_range=0           ; Specify the port range for socket binding, relative to the start
                                ; port number specified in port.
        id_uri=sip:telegram@127.0.0.1
                                ; The Address of Record or AOR, that is full SIP URL that identifies the account.
                                ; The value can take name address or URL format, and will look something
                                ; like "sip:account@serviceprovider".

        callback_uri=sip:telegram@127.0.0.1:5060 ; FIXME: unhardcode the port
                                ; SIP URI for TG->SIP incoming calls processing

        raw_pcm=false           ; use L16@48k codec if true or OPUS@48k otherwise
                                ; keep true for lower CPU consumption

        ;thread_count=1         ; Specify the number of worker threads to handle incoming RTP
                                ; packets. A value of one is recommended for most applications.

        [telegram]
        api_id=2631010 ; FIXME: Application identifier for Telegram API access
        api_hash=899a7e59e30e2be5a55cbb488984a1eb ; FIXME: Application identifier hash for Telegram API access
                                                  ; which can be obtained at https://my.telegram.org.

        system_language_code=ru-RU      ; IETF language tag of the user's operating system language

        [other]
        extra_wait_time=10             ; If gateway gets temporary blocked with "Too Many Requests" reason,
                                       ; then block all outgoing telegram requests for X more seconds than was
                                       ; requested by server
        ;peer_flood_time=86400         ; Seconds to wait on PEER_FLOOD
      '';
    };
  };

          # ; same => n,System(${python-scripts}/bin/telegram_send.py "${telegram_session}" "${telegram_secret}" ''${EPOCH} ''${DONGLENAME} --from-name=''${CALLERID(num)} --message-base64=''${SMS_BASE64})
in
  local.collection
