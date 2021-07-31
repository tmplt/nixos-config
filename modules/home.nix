let secrets = import ../secrets;
in { pkgs, config, lib, ... }: {
  home.sessionPath = [ "/home/tmplt/.cargo/bin" ];

  home.file = { ".emacs.d/init.el".source = ../dotfiles/emacs.el; };

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
      passwordCommand =
        "${pkgs.getmail}/bin/getmail-gmail-xoauth-tokens ~/nixops/secrets/gmail.uni.json";

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
  programs.mbsync.package = with pkgs;
    isync.overrideAttrs (old: { buildInputs = [ openssl db gsasl zlib ]; });
  programs.offlineimap.enable = true;
  programs.mu.enable = true;
  programs.msmtp.enable = true;
  services.mbsync = {
    enable = true;
    frequency = "*:0/1"; # every minute
    package = with pkgs;
      isync.overrideAttrs (old: { buildInputs = [ openssl db gsasl zlib ]; });
    preExec = ''
      ${pkgs.coreutils}/bin/mkdir -p %h/mail/{tmplt,personal,ludd,personal}
    '';

    # FIXME mbsync isn't yet packaged to properly auth with gmail.
    # See <https://github.com/NixOS/nixpkgs/issues/108480>.
    postExec = with pkgs;
      "${writeScript "mbsync-post" ''
        #!${stdenv.shell}
        ${pkgs.offlineimap}/bin/offlineimap -a uni || exit $?

        ${pkgs.mu}/bin/mu index --quiet
        # If the DB is already locked by mu4e, don't fail
        retval=$?
        [[ $retval -eq 19 ]] && exit 0 || exit $retval
      ''}";
  };

  manual.manpages.enable = true;

  programs.bash = {
    enable = true;

    initExtra = ''
      eval "$(${pkgs.zoxide}/bin/zoxide init bash)"
    '';

    shellAliases = {
      nixre = "doas nixos-rebuild switch --flake ~/nixops";
      nixrt = "doas nixos-rebuild test --flake ~/nixops";
      nixrb = "doas nixos-rebuild build --flake ~/nixops";
    };
  };

  programs.git = {
    enable = true;
    userName = "Viktor Sonesten";
    userEmail = "v@tmplt.dev";
    package = pkgs.gitAndTools.gitFull;

    extraConfig = {
      github.user = "tmplt";
    };
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "GohuFont:style=regular:antialias=false:pixelsize=11";
        pad = "10x10";
        term = "xterm-256color";
      };

      colors = {
        foreground = "c2c2b0";
        background = "303030";
        regular0 = "000000"; # black
        regular1 = "d54e53"; # red
        regular2 = "b0ca4a"; # green
        regular3 = "e6c547"; # yellow
        regular4 = "7aa6da"; # blue
        regular5 = "c397d8"; # magenta
        regular6 = "70c0ba"; # cyan
        regular7 = "ffffff"; # white
        bright0 = "000000"; # bright black
        bright1 = "d54e53"; # bright red
        bright2 = "b0ca4a"; # bright green
        bright3 = "e6c547"; # bright yellow
        bright4 = "7aa6da"; # bright blue
        bright5 = "c397d8"; # bright magenta
        bright6 = "70c0ba"; # bright cyan
        bright7 = "ffffff"; # bright white
      };
    };
  };

  programs.emacs = {
    enable = true;
    package = pkgs.emacsWithPackagesFromUsePackage {
      config = ../dotfiles/emacs.el;
      package = pkgs.emacsPgtk;
      alwaysEnsure = true;
      extraEmacsPackages = epkgs: with epkgs; [ ];
    };
  };
  home.packages = with pkgs; [
    # needed by pdf-tools
    imagemagick
    # needed by mu4e
    msmtp
    # needed by rustic
    pandoc
    ripgrep
    fd

    wl-clipboard # may come in handy
  ];

  programs.qutebrowser = {
    enable = true;

    settings = {
      # infinite history eventually bogs command input down to a crawl,
      # and I/O issues (duplicating keys) manifest.
      completion.web_history.max_items = 250;

      confirm_quit = [ "downloads" ];
      content.autoplay = false;
    };

    enableDefaultBindings = false;
    keyBindings = let
      escapes = {
        "<Escape>" = "mode-leave";
        "<Ctrl-g>" = "mode-leave";
      };
      rls = {
        "<Ctrl-b>" = "rl-backward-char";
        "<Ctrl-f>" = "rl-forward-char";
        "<Alt-b>" = "rl-backward-word";
        "<Alt-f>" = "rl-forward-word";
        "<Ctrl-a>" = "rl-beginning-of-line";
        "<Ctrl-e>" = "rl-end-of-line";
        "<Ctrl-u>" = "rl-unix-line-discard";
        "<Ctrl-k>" = "rl-kill-line";
        "<Alt-d>" = "rl-kill-word";
        "<Ctrl-w>" = "rl-unix-word-rubout";
        "<Alt-Backspace>" = "rl-backward-kill-word";
        "<Ctrl-?>" = "rl-delete-char";
        "<Ctrl-h>" = "rl-backward-delete-char";
        "<Ctrl-y>" = "rl-yank";
      };
    in {
      normal = {
        # Navigation
        "<Ctrl-v>" = "scroll-page 0 0.5";
        "<Alt-v>" = "scroll-page 0 -0.5";
        "<Ctrl-Shift-v>" = "scroll-page 0 1";
        "<Alt-Shift-v>" = "scroll-page 0 -1";
        # FIXME come up with logical bindings for scrolling left/right

        # Commands
        "<Alt-x>" = "set-cmd-text :";
        "<Ctrl-x>b" = "set-cmd-text -s :buffer";
        "<Ctrl-x><Ctrl-c>" = "quit";

        # searching
        "<Ctrl-s>" = "set-cmd-text /";
        "<Ctrl-r>" = "set-cmd-text ?";

        # hinting
        "<Ctrl-Space>" = "hint";
        "<Ctrl-u><Ctrl-Space>" = "hint --rapid links tab-bg";
        "<Ctrl-x>m" = "hint links spawn mpv {hint-url}";

        "<Ctrl-x>r" = "reload";
        "<Ctrl-x>cd" = "download-clear";
        "<Ctrl-x>u" = "undo";

        # history
        "<Ctrl-f>" = "forward";
        "<Ctrl-b>" = "back";

        # tabs
        "<Ctrl-x>0" = "tab-close";
        "<Ctrl-x>1" = "tab-only";
        "<Alt-a>" = "tab-prev";
        "<Alt-e>" = "tab-next";

        # open links
        "<Ctrl-l>" = "set-cmd-text -s :open";
        "<Alt-l>" = "set-cmd-text -s :open -t";

        # editing
        "<Ctrl-a>" = "fake-key <Home>";
        "<Ctrl-e>" = "fake-key <End>";
        "<Ctrl-n>" = "fake-key <Down>";
        "<Ctrl-p>" = "fake-key <Up>";
        "<Alt-f>" = "fake-key <Ctrl-Right>";
        "<Alt-b>" = "fake-key <Ctrl-Left>";
        "<Ctrl-d>" = "fake-key <Delete>";
        "<Alt-d>" = "fake-key <Ctrl-Delete>";
        "<Alt-backspace>" = "fake-key <Ctrl-Backspace>";
        "<Ctrl-w>" = "yank";
        "<Ctrl-y>" = "insert-text {primary}";

        # Numbers
        # <https://github.com/qutebrowser/qutebrowser/issues/4213>
        "1" = "fake-key 1";
        "2" = "fake-key 2";
        "3" = "fake-key 3";
        "4" = "fake-key 4";
        "5" = "fake-key 5";
        "6" = "fake-key 6";
        "7" = "fake-key 7";
        "8" = "fake-key 8";
        "9" = "fake-key 9";
        "0" = "fake-key 0";

        "<Ctrl-h>" = "set-cmd-text -s :help";
      } // escapes;

      command = {
        "<Ctrl-s>" = "search-next";
        "<Ctrl-r>" = "search-prev";

        "<Ctrl-p>" = "completion-item-focus prev";
        "<Ctrl-n>" = "completion-item-focus next";

        "<Alt-p>" = "command-history-prev";
        "<Alt-n>" = "command-history-next";

        "<Return>" = "command-accept";
      } // escapes // rls;

      prompt = {
        "<Return>" = "prompt-accept";
        "<Ctrl-p>" = "prompt-item-focus prev";
        "<Ctrl-n>" = "prompt-item-focus next";
        "<Alt-y>" = "prompt-yank";
        "<Alt-Shift-y>" = "prompt-yank --sel";
      } // escapes // rls;

      yesno = {
        "y" = "prompt-accept yes";
        "n" = "prompt-accept no";
      } // escapes;

      hint = { } // escapes;
      caret = { } // escapes;
      insert = { } // escapes // rls;
    };
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
    wrapperFeatures = { gtk = true; };

    config = let
      swaylock =
        "${pkgs.swaylock}/bin/swaylock --show-keyboard-layout --image ${
          ../wallpapers/lock.jpg
        }";
    in rec {
      modifier = "Mod4"; # effectively unused
      terminal = "${pkgs.foot}/bin/foot";

      keybindings = let mod = modifier;
      in lib.mkOptionDefault {
        "XF86ScreenSaver" = "exec ${swaylock}";
        "Ctrl+t" = "mode stumpwm";
      };

      modes = let
        escapes = {
          "Ctrl+g" = "mode default";
          "Escape" = "mode default";
        };
      in lib.mkOptionDefault {
        stumpwm = let
          run-or-raise = pkgs.writeShellScript "sway-run-or-raise" ''
            prog="$@"
            ${pkgs.procps}/bin/pkill -0 ''${prog} || {
              ''${prog} &
              exit 0
            }
            swaymsg "[app_id=''${prog}] focus" || swaymsg "[class=''${prog}] focus"
          '';
          exec = cmd: "exec 'swaymsg ${cmd}; swaymsg mode default'";
          exec' = cmd: "exec 'swaymsg mode default; ${cmd}'";
        in {
          # launch common programs
          "c" = exec' terminal;
          "Ctrl+c" = exec' terminal;
          "e" = exec' "${run-or-raise} emacs";
          "Ctrl+e" = exec' "${run-or-raise} emacs";
          "q" = exec' "${run-or-raise} qutebrowser";
          "Ctrl+q" = exec' "${run-or-raise} qutebrowser";

          # dmenu
          "d" = exec' "dmenu_run";

          # kill window
          "k" = exec "kill";

          # navigation
          "Ctrl+p" = exec "workspace prev";
          "Ctrl+n" = exec "workspace next";
          "Space" = exec "workspace next";
          "n" = exec "focus down";
          "p" = exec "focus up";
          "f" = exec "focus right";
          "b" = exec "focus left";

          # fullscreen
          "Return" = exec "fullscreen toggle";

          # splitting
          "s" = exec "split vertical";
          "Shift+s" = exec "split horizontal";

          # window switcher, adapted from <https://github.com/AdrienLeGuillou/sway_window_swithcher_dmenu/blob/master/sws.sh>.
          "w" = exec' (pkgs.writeShellScript "sway-window-switcher" ''
            # Get the container ID from the node tree
            CON_ID=$(swaymsg -t get_tree | \
                ${pkgs.jq}/bin/jq -r ".nodes[]
                    | {output: .name, content: .nodes[]}
                    | {output: .output, workspace: .content.name,
                      apps: .content
                        | ..
                        | {id: .id?|tostring, name: .name?, app_id: .app_id?, shell: .shell?}
                        | select(.app_id != null or .shell != null)}
                    | {output: .output, workspace: .workspace,
                       id: .apps.id, app_id: .apps.app_id, name: .apps.name }
                    | \"W:\" + .workspace + \" | \" + .app_id + \" - \" + .name + \" (\" + .id + \")\"
                    | tostring" | \
                ${pkgs.dmenu}/bin/dmenu -i -p "Window Switcher")

            # Requires the actual `id` to be at the end and between paretheses
            CON_ID=''${CON_ID##*(}
            CON_ID=''${CON_ID%)}

            # Focus on the chosen window
            swaymsg [con_id=$CON_ID] focus
          '');

          # TODO(t) sent <C-t>; wait for <https://github.com/swaywm/sway/issues/1779>
        } // escapes;
      };

      startup = [
        {
          command =
            "${pkgs.swayidle}/bin/swayidle -w timeout 300 '${swaylock}' before-sleep '${swaylock}'";
        }
        { command = "emacs"; }
      ];

      output = { "*" = { bg = "${../wallpapers/bg.jpg} fill"; }; };

      input = {
        "*" = {
          xkb_layout = "us";
          xkb_variant = "colemak";
          xkb_options = "ctrl:nocaps,compose:menu,compose:rwin";
          repeat_delay = "300";
          repeat_rate = "35";
        };
      };

      seat = { "*" = { hide_cursor = "8000"; }; };
    };
  };

  services.gammastep = {
    # FIXME kill immidiately on SIGTERM. Don't wait for it to dim
    # back; that blocks WM termination.
    enable = true;
    provider = "geoclue2";
  };
}
