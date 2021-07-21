{ config, pkgs, ... }:
let
  emacs = pkgs.emacsWithPackagesFromUsePackage {
    config = ./emacs.el;
    package = pkgs.emacsPgtkGcc;
    alwaysEnsure = true;
    extraEmacsPackages = epkgs: with epkgs; [
      modus-operandi-theme
      modus-vivendi-theme
    ];
  };
in
{
  services.emacs = {
    enable = true;
    package = emacs;
    defaultEditor = true;
  };

  environment.systemPackages = with pkgs; [
    emacs

    imagemagick # needed by pdf-tools
    msmtp # needed by mu4e
    pandoc ripgrep fd # needed by rustic
  ];
}
