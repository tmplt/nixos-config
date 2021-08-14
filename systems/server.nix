{ pkgs, lib, ... }:
let
  sshKeys = import ../ssh-keys.nix;
  secrets = import ../secrets;
in
rec {
  deployment.targetHost = "praecursoris.campus.ltu.se";
  time.timeZone = "Europe/Stockholm";

  imports = [
    ../hardware-configurations/server.nix
    <nixpkgs/nixos/modules/profiles/headless.nix>
  ];

  # TODO: limit command set to only allow that of backing up data
  users.users.root.openssh.authorizedKeys.keys = [ sshKeys.backup ];

  environment.systemPackages = with pkgs; [
    lz4 # required by zfs-replicate from systems/nas
  ];

  networking = {
    hostName = "praecursoris";
    hostId = "61ceb5ac";

    interfaces.enp4s0.ipv4.addresses = [{
      address = "130.240.202.140";
      prefixLength = 24;
    }];

    defaultGateway = "130.240.202.1";
    nameservers = [ "130.240.16.8" ];
  };

  boot.loader.grub = {
    enable = true;
    version = 2;
    devices = [ "/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" ];
  };
  boot.supportedFilesystems = [ "zfs" ];

  nix.trustedUsers = [ "root" "@builders" ];
  users.groups.builders = { };
  users.users.builder = {
    isNormalUser = false;
    isSystemUser = true;
    group = "builders";
    useDefaultShell = true;
    openssh.authorizedKeys.keys = [ sshKeys.builder ];
  };

  services.syncthing = rec {
    enable = true;
    openDefaultPorts = true;
    dataDir = "/var/lib/syncthing";
    declarative = {
      devices.perscitia = {
        id = secrets.syncthing.laptopID;
        introducer = true;
      };

      folders."${dataDir}/sync" = {
        devices = [ "perscitia" ];
        label = "sync";
      };

      folders."${dataDir}/org" = {
        devices = [ "perscitia" ];
        label = "org";
      };
    };
  };

  services.murmur = {
    enable = true;
    hostName = (lib.head networking.interfaces.enp4s0.ipv4.addresses).address;
    password = (import ../secrets).murmurPasswd;
    imgMsgLength = 2 * 1024 * 1024; # 2Mi
    registerName = "Draknästet";
    bandwidth = 128000;

    # TODO: PR options for these
    extraConfig = ''
      username=.*
      channelname=.*
      rememberchannel=false
      defaultchannel=67
      suggestVersion=1.3.0
      opusthreshold=0
    '';

    sslCert = "/var/lib/acme/mumble.dragons.rocks/fullchain.pem";
    sslKey = "/var/lib/acme/mumble.dragons.rocks/key.pem";
  };
  security.acme = {
    email = "v@tmplt.dev";
    acceptTerms = true;
  };
  security.acme.certs."mumble.dragons.rocks" = {
    group = "mumble-dragons-rocks";

    # Tell murmur to reload its SSL settings, if it is running
    postRun = ''
      if ${pkgs.systemd}/bin/systemctl is-active murmur.service; then
        ${pkgs.systemd}/bin/systemctl kill -s SIGUSR1 murmur.service
      fi
    '';
  };
  users.groups."mumble-dragons-rocks".members = [ "murmur" "nginx" ];

  # TODO: polling is ugly; can we manage this with a git web-hook instead?
  systemd.services.update-homepage = {
    description = "Init/update tmplt.dev homepage";
    serviceConfig.User = "nginx";
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ git ];
    script = ''
      mkdir -p /var/lib/www/tmplt.dev
      cd /var/lib/www/tmplt.dev
      if [ ! $(git rev-parse --is-inside-work-tree) ]; then
        git clone https://github.com/tmplt/tmplt.dev.git .
      else
        git fetch origin master
        git reset --hard origin/master
      fi
    '';
    startAt = "hourly";
    wantedBy = [ "multi-user.target" ];
    before = [ "nginx.service" ];
  };

  systemd.services.init-passwd = {
    description = "Init passwd.git repository";
    serviceConfig.User = "tmplt";
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ git ];
    script = ''
      set -euox pipefail
      mkdir -p ~/passwd.git && cd ~/passwd.git
      if [ ! $(git rev-parse --is-inside-work-tree) ]; then
        git init --bare .
      fi
    '';
    wantedBy = [ "multi-user.target" ];
  };

  networking.firewall.allowedTCPPorts = [
    80 443 # nginx
    64738  # murmur
  ];
  networking.firewall.allowedUDPPorts = [
    64738 # murmur
  ];

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts = {
      "tmplt.dev" = {
        forceSSL = true;
        enableACME = true;
        default = true;
        # TODO: deny access to all hidden files instead
        locations."~ /\.git".extraConfig = "deny all;";
        locations."/".root = "/var/lib/www/tmplt.dev";
      };

      "www.tmplt.dev" = {
        forceSSL = true;
        enableACME = true;
        locations."/".extraConfig = "return 301 $scheme://tmplt.dev$request_uri;";
      };

      "mumble.dragons.rocks" = {
        forceSSL = true;
        enableACME = true;
      };
    };
  };

  users.groups.libvirtd.members = [ "root" "tmplt" ];
  virtualisation.libvirtd.enable = true;

  system.stateVersion = "19.09";
}
