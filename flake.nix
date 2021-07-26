{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05-small";
    home-manager.url = "github:nix-community/home-manager/release-21.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    emacs.url = "github:nix-community/emacs-overlay/master";
  };

  outputs = { self, nixpkgs, home-manager, nixos-hardware, emacs, ... }: {

    nixosConfigurations = {
      perscitia = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-hardware.nixosModules.lenovo-thinkpad-x220

          ./systems/laptop.nix

          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [ emacs.overlay ];

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.tmplt = import ./modules/home.nix;
          }
        ];
      };

      # TODO add servers here when nixops properly supports flakes. We
      # cannot use flakes because of `deployment.keys`.
    };
  };
}
