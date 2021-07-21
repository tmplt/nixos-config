{ config, pkgs, ... }:

{
  imports = [
    ../hardware-configurations/laptop.nix
    ../modules/wlan.nix
    ../modules/packages.nix
  ];

  # Basic options

  fileSystems."/".options = [ "noatime" "nodiratime" "discard" ];
  # Configure unlock for the encrypted root (/) partition.
  boot.initrd.luks.devices.root = {
    name = "root";
    device = "/dev/disk/by-uuid/${
            pkgs.lib.removeSuffix "\n"
            (builtins.readFile ../hardware-configurations/laptop-luks.uuid)
          }";
    preLVM = true;
    allowDiscards = true;
  };
  boot.loader.systemd-boot.enable = true;

  hardware = {
    pulseaudio.enable = true;
    # Don't mute audio streams when VOIP programs are running.
    pulseaudio.extraConfig = ''
      unload-module module-role-cork
    '';

    trackpoint.enable = true;
    trackpoint.emulateWheel = true;

    bluetooth.enable = true;
  };

  networking.hostName = "perscitia";
  networking.useDHCP = true;
  time.timeZone = "Europe/Stockholm";
  sound.enable = true;

  # User options

  users.extraUsers.tmplt = {
    description = "Viktor Sonsten";
    isNormalUser = true;
    uid = 1000; # for NFS permissions

    extraGroups = [ "wheel" "dialout" "video" "audio" "input" "libvirtd" ];

    # Don't forget to set an actual password with passwd(1).
    initialPassword = "password";
  };

  # Make the default download directory a tmpfs, so I don't end up
  # using it as a non-volatile dir for whatever.
  #
  # TODO derive path from above attribute
  fileSystems."/home/tmplt/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "rw" "size=20%" "uid=tmplt" ];
  };

  programs.light.enable = true;

  services.xserver = {
    enable = false; # but still here so we can copy the XKB config to TTYs
    xkbVariant = "colemak";
    xkbOptions = "ctrl:nocaps,compose:menu,compose:rwin";
    autoRepeatDelay = 300;
    autoRepeatInterval = 35;
  };
  console.useXkbConfig = true;

  programs.sway.enable = true;
  hardware.opengl.enable = true;

  # Convenience symlinks for emacs, offlineimap
  environment.etc = {
    "nix/pins/cacert".source = pkgs.cacert;
    "nix/pins/mu".source = pkgs.mu;
  };

  # Fix for USB redirection in virt-manager(1).
  security.wrappers.spice-client-glib-usb-acl-helper.source =
    "${pkgs.spice_gtk}/bin/spice-client-glib-usb-acl-helper";
  environment.systemPackages = with pkgs; [ spice_gtk ];

  # System services

  systemd.coredump.enable = true;
  services.geoclue2.enable = true;
  services.udisks2.enable = true;
  services.dictd.enable = true;
  services.acpid.enable = true;
  services.thermald.enable = true;
  virtualisation.libvirtd.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Misc. options

  # Allow certain USB interfaces to be accessed without root privelages.
  services.udev.extraRules = with pkgs.lib;
    let
      toUdevRule = vid: pid: ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="${vid}", ATTR{idProduct}=="${pid}", TAG+="uaccess", RUN{builtin}+="uaccess" MODE:="0666"
      '';
      setWorldReadable = idPairs:
        concatStrings
          (map (x: let l = splitString ":" x; in toUdevRule (head l) (last l))
            idPairs);
    in
    (setWorldReadable [
      "0483:374b"
      "0483:3748"
      "0483:3752" # ST-LINK/V2.1 rev A/B/C+
      "15ba:002a" # ATM-USB-TINY-H JTAG interface
      "1366:1015" # SEGGER (JLink firmware)
      "0403:6014" # FT232H
    ]) +
    # Shutdown system on low battery level to prevents fs corruption
    ''
      KERNEL=="BAT0" \
      , SUBSYSTEM=="power_supply" \
      , ATTR{status}=="Discharging" \
      , ATTR{capacity}=="[0-5]" \
      , RUN+="${pkgs.systemd}/bin/systemctl poweroff"
    '';

  fileSystems."/mnt/dulcia" = {
    device = "dulcia.localdomain:/rpool/media";
    fsType = "nfs";
    options = [
      "defaults" # XXX: is this causing us issues?
      "noexec"
      "noauto"
      "nofail"

      # Don't retry NFS requests indefinitely.
      # XXX: can cause data corruption, but its responsiveness I'm after.
      "soft"

      "timeo=1" # 0.1s before sending the next NFS request
      "retry=0"
      "retrans=10"

      "x-systemd.automount"
      "x-systemd.mount-timeout=1s"
    ];
  };

  nix = {
    package = pkgs.nixUnstable;

    distributedBuilds = true;
    buildMachines = [{
      hostName = "tmplt.dev";
      sshUser = "builder";
      sshKey = "/home/tmplt/.ssh/id_builder";
      systems = [ "x86_64-linux" "aarch64-linux" ];
      maxJobs = 12;
      supportedFeatures = [ "big-parallel" ]; # build Linux
    }];

    # Builder has much faster Internet connection.
    extraOptions = ''
      builders-use-substitutes = true
      experimental-features = nix-command flakes
    '';
  };

  # Hibernate after the lid has been closed for 1h.
  #
  # TODO add some 10min delay before we go to sleep? (that is, 10min
  # of nothing when lid is closed)
  environment.etc."systemd/sleep.conf".text = "HibernateDelaySec=1h";
  services.logind = {
    lidSwitch = "suspend-then-hibernate";
    lidSwitchDocked = "suspend-then-hibernate";

    # See logind.conf(5).
    extraConfig = ''
      HandleSuspendKey=ignore
      handleHibernateKey=hibernate

      PowerKeyIgnoreInhibited=yes
      SuspendKeyIgnoreInhibited=yes
      HibernateKeyIgnoreInhibited=yes
      LidSwitchIgnoreInhibited=yes
    '';
  };

  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  systemd.extraConfig = ''
    DefaultTimeoutStopSec=30s
  '';

  system.stateVersion = "18.03";

}
