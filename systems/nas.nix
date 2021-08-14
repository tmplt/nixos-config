{ pkgs, ... }:
let
  secrets = (import ../secrets);
in
{
  deployment.targetHost = "home.tmplt.dev";
  time.timeZone = "Europe/Stockholm";
  networking.hostName = "dulcia";
  networking.hostId = "61ceb5ad";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.enp10s0f0.useDHCP = true;
  networking.interfaces.enp10s0f1.useDHCP = true;
  networking.interfaces.enp4s0.useDHCP = true;
  networking.interfaces.enp9s0f0.useDHCP = true;
  networking.interfaces.enp9s0f1.useDHCP = true;

  imports = [
    ../hardware-configurations/nas.nix
    <nixpkgs/nixos/modules/profiles/headless.nix>
    ../modules/htpc.nix
  ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub = {
    enable = true;
    version = 2;
    devices = [
      "/dev/disk/by-id/ata-WDC_WD60EFRX-68L0BN1_WD-WX11D76EPVX7"
      "/dev/disk/by-id/ata-WDC_WD60EFRX-68L0BN1_WD-WX31D95842XA"
    ];
  };
  boot.supportedFilesystems = [ "zfs" ];

  environment.systemPackages = with pkgs; [
    beets
    ffmpeg
    aria2
  ];

  services.zfs.autoReplication = {
    enable = true;
    username = "root"; # TODO: use a dedicated backup user <https://github.com/openzfs/zfs/issues/7294>
    host = "tmplt.dev";
    identityFilePath = /root/.ssh/id_backup;
    localFilesystem = "rpool/media/music";
    remoteFilesystem = "rpool/backups";
    followDelete = true;
  };

  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /rpool/media         perscitia.localdomain(rw,crossmnt,no_subtree_check)
  '';

  services.samba = {
    enable = true;
    extraConfig = ''
      mangled names = no
    '';
    shares.media = {
      path = "/rpool/media";
      browsable = "yes";
      "read only" = "no";
      "guest ok" = "no";
      comment = "Public SMB share.";
    };
    shares.volatile = {
      path = "/vpool";
      browsable = "yes";
      "read only" = "no";
      "guest ok" = "no";
      comment = "Public volatile SMB share.";
    };
    # XXX Don't forget to set credentials:
    #
    #    # nix-shell -p samba --run "smbpasswd -a tmplt"
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts = {
      "public.dragons.rocks" = {
        locations."/" = {
          root = "/rpool/media/public";
          extraConfig = ''
            autoindex on;
          '';
        };
      };
    };
  };
  security.acme = {
    email = "v@tmplt.dev";
    acceptTerms = true;
  };

  services.mpd = {
    enable = true;
    user = "tmplt";
    group = "users";
    musicDirectory = "/rpool/media/music";
    extraConfig = ''
      password "${secrets.dulcia.mpdPassword}@read,control,add,admin"
      bind_to_address "192.168.1.246"
      port "6600"
      max_output_buffer_size "${toString (8192 * 16)}"

      audio_output {
                   type "httpd"
                   name "HTTPD Stream"
                   port "8000"
                   encoder "vorbis"
                   bitrate "128"
                   format "44100:16:1"
                   always_on "yes"
                   tags "yes"
      }
    '';
  };

  services.icecast = {
    enable = false;
    admin.password = secrets.dulcia.icecast.adminPassword;
    hostname = "den.dragons.rocks";
    listen.port = 8000;
    extraConf = ''
      <authentication>
        <source-password>${secrets.dulcia.icecast.sourcePassword}</source-password>
      </authentication>
    '';
  };

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    dataDir = "/rpool/media/sync";
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    6600 8000 # MPD
    2049 111 20048 # NFS
    139 445 # SMB
    80 443 # nginx
  ];
  networking.firewall.allowedUDPPorts = [
    137 138 # SMB
  ];

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.09"; # Did you read the comment?
}
