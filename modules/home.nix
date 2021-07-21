let secrets = import ../secrets; in
{ pkgs, config, ... }: {
  home.sessionPath = [ "/home/tmplt/.cargo/bin" ];

  accounts.email.maildirBasePath = "mail";
  accounts.email.accounts = {
    "tmplt" = rec {
      primary = true;
      address = "v@tmplt.dev";
      aliases = [ "tmplt@dragons.rocks" ];
      userName = address;
      flavor = "plain";
      folders = {
        inbox = "INBOX";
        trash = "Junk";
      };
      imap = {
        host = "imap.migadu.com";
        port = 993;
        tls.enable = true;
      };
      smtp = {
        host = "smtp.migadu.com";
        port = 587;
        tls.enable = true;
        tls.useStartTls = true;
      };
      passwordCommand = "echo ${secrets.emails.tmplt}";

      mbsync.enable = true;
      mbsync.create = "both";

      mu.enable = true;
      msmtp.enable = true;
    };

    "personal" = rec {
      address = "viktor.sonesten@mailbox.org";
      userName = address;
      flavor = "plain";
      folders.inbox = "INBOX";
      imap = {
        host = "imap.mailbox.org";
        port = 993;
        tls.enable = true;
      };
      smtp = {
        host = "smtp.mailbox.org";
        port = 587;
        tls.enable = true;
        tls.useStartTls = true;
      };
      passwordCommand = "echo ${secrets.emails.personal}";

      mbsync.enable = true;
      mbsync.create = "both";

      mu.enable = true;
      msmtp.enable = true;
    };

    "ludd" = rec {
      address = "tmplt@ludd.ltu.se";
      userName = "tmplt";
      flavor = "plain";
      folders.inbox = "INBOX";
      imap = {
        host = "imaphost.ludd.ltu.se";
        port = 993;
        tls.enable = true;
      };
      smtp = {
        host = "mailhost.ludd.ltu.se";
        port = 465;
      };
      passwordCommand = "echo ${secrets.emails.ludd}";

      mbsync.enable = true;
      mbsync.create = "both";

      mu.enable = true;
      msmtp.enable = true;
      msmtp.extraConfig.tls_starttls = "off";
    };

    "uni" = rec {
      address = "vikson-6@student.ltu.se";
      aliases = [ "viktor.vilhelm.sonesten@alumni.cern" ];
      userName = address;
      flavor = "gmail.com";
      passwordCommand = "${pkgs.getmail}/bin/getmail-gmail-xoauth-tokens ~/nixops/secrets/gmail.uni.json";

      offlineimap = {
        enable = true;
        extraConfig.remote = secrets.emails.uniRemoteConfig;
      };
      mu.enable = true;
      msmtp.enable = true;
      msmtp.extraConfig.auth = "oauthbearer";
    };
  };
  programs.mbsync.enable = true;
  programs.mbsync.package = with pkgs; isync.overrideAttrs (old: {
    buildInputs = [ openssl db gsasl zlib ];
  });
  programs.offlineimap.enable = true;
  programs.mu.enable = true;
  programs.msmtp.enable = true;
  services.mbsync = {
    enable = true;
    frequency = "*:0/1"; # every minute
    package = with pkgs; isync.overrideAttrs (old: {
      buildInputs = [ openssl db gsasl zlib ];
    });
    preExec = ''
      ${pkgs.coreutils}/bin/mkdir -p %h/mail/{tmplt,personal,ludd,personal}
    '';

    # FIXME mbsync isn't yet packaged to properly auth with gmail.
    # See <https://github.com/NixOS/nixpkgs/issues/108480>.
    postExec = with pkgs; "${writeScript "mbsync-post" ''
      #!${stdenv.shell}
      ${pkgs.offlineimap}/bin/offlineimap -a uni || exit $?

      ${pkgs.mu}/bin/mu index --quiet
      # If the DB is already locked by mu4e, don't fail
      retval=$?
      [[ $retval -eq 19 ]] && exit 0 || exit $retval
    ''}";
  };

  manual.manpages.enable = true;

  programs.git = {
    enable = true;
    userName = "Viktor Sonesten";
    userEmail = "v@tmplt.dev";
    package = pkgs.gitAndTools.gitFull;
  };

  home.packages = with pkgs; [
    # for wayland
    swaylock
    swayidle
    wl-clipboard
    alacritty
    dmenu
  ];

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  programs.ssh = {
    enable = true;
    compression = true;
    serverAliveInterval = 5;

    matchBlocks = secrets.sshHosts // {
      "*".identityFile = "~/.ssh/id_ecdsa";
      "github.com".identitiesOnly = true;

      "kobo" = {
        hostname = "192.168.2.190";
        user = "root";
      };

      "builder" = {
        hostname = "tmplt.dev";
        user = "builder";
        identityFile = "~/.ssh/id_builder";
      };

      "pi" = {
        hostname = "tmplt.dev";
        user = "root";
        port = 21013;
        extraOptions = { StrictHostKeyChecking = "no"; };
      };
    };
  };

  programs.autorandr =
    let
      laptopEDID = "00ffffffffffff0030e4d3020000000000150103801c1078ea10a59658578f2820505400000001010101010101010101010101010101381d56d45000163030202500159c1000001b000000000000000000000000000000000000000000fe004c4720446973706c61790a2020000000fe004c503132355748322d544c423100f7";
      dockedEDID = "00ffffffffffff0022f057290000000025160104b53c2278222e25a7554d9e260c505420000081c00101010101010101010101010101565e00a0a0a029503020220255502100001a1a1d008051d01c204080750055502100001e000000fc004850205a5232373430770a2020000000ff00434e54323337573046560a2020009f";
      workEDID = "00ffffffffffff00410c42c1f41b00000b1b0104b55932783a1571ad5047a726125054bfef00d1c0b30095008180814081c0010101014dd000a0f0703e803020350075f23100001aa36600a0f0701f803020350075f23100001a000000fd0017501ea03c010a202020202020000000fc0050484c2042444d34303337550a0194020326f14b0103051404131f1202119023090707830100006d030c0020001878200060010203011d007251d01e206e28550075f23100001e8c0ad08a20e02d10103e960075f2310000188c0ad090204031200c40550075f2310000184d6c80a070703e8030203a0075f23100001a000000000000000000000000000000000025";
    in
    {
      enable = true;
      profiles = {
        "mobile" = {
          fingerprint.LVDS-1 = laptopEDID;
          config = {
            LVDS-1 = {
              enable = true;
              mode = "1366x768";
            };
          };
        };

        "docked" = {
          fingerprint.LVDS-1 = laptopEDID;
          fingerprint.DP-2 = dockedEDID;
          config = {
            LVDS-1 = {
              enable = true;
              mode = "1366x768";
            };
            DP-2 = {
              enable = true;
              mode = "2560x1440";
              position = "1366x0";
            };
          };
        };

        "work" = {
          fingerprint.LVDS-1 = laptopEDID;
          fingerprint.DP-1 = workEDID;
          config = {
            LVDS-1.enable = false;
            DP-1 = {
              enable = true;
              mode = "3840x2160";
            };
          };
        };
      };

      hooks.postswitch = {
        "change-background" = "${pkgs.systemd}/bin/systemctl --user start random-background";
      };
    };

  services.mpd = {
    enable = true;
    musicDirectory = "/mnt/dulcia/music";
    extraConfig = ''
      audio_output {
          type    "pulse"
          name    "Local pulseaudio output"
      }
    '';
  };

  xdg = {
    userDirs = {
      enable = true;
      download = "$HOME/tmp";
    };

    mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = [ "org.pwmt.zathura.desktop" ];
        "x-scheme-handler/https" = [ "qutebrowser.desktop" ];
        "x-scheme-handler/http" = [ "qutebrowser.desktop" ];
        "image/png" = [ "sxiv.desktop" ];
        "image/jpeg" = [ "sxiv.desktop" ];
      };
    };
  };

  home.keyboard = {
    layout = "us,us";
    options = [ "caps:ctrl_modifier" "compose:prsc" "grp:rctrl_toggle" ];
    variant = "colemak,";
  };

  services.syncthing = {
    enable = true;
    tray = false;
  };

  # Graphical services

  wayland.windowManager.sway = {
    enable = true;
    systemdIntegration = true;
    wrapperFeatures = {
      gtk = true;
    };

    config = {
      modifier = "Mod4";
      terminal = "${pkgs.foot}/bin/foot";
    };

    extraConfig = ''
      input * {
        xkb_layout us
        xkb_variant colemak
        xkb_options ctrl:nocaps,compose:menu,compose:rwin
        repeat_delay 300
        repeat_rate 35
      }

      seat * hide_cursor 8000

      bindsym Mod4+Control+e exec emacsclient --create-frame --alternate-editor="";
      bindsym Mod4+x exec dmenu_run
    '';
  };

  services.screen-locker = {
    enable = true;
    inactiveInterval = 10; # lock after 10min of inactivity
    lockCmd = "${pkgs.swaylock}/bin/swaylock -ni /home/tmplt/wallpapers/shoebill.png";
  };

  services.random-background = {
    enable = false;
    enableXinerama = true;
    imageDirectory = "%h/wallpapers";
  };

  services.gammastep = {
    # FIXME kill immidiately on SIGTERM. Don't wait for it to dim
    # back; that blocks WM termination.
    enable = true;
    provider = "geoclue2";
  };
}
