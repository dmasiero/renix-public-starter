{ config, lib, pkgs, ... }:
let
  tauDir = "${config.home.homeDirectory}/.tau";
in
{
  home.packages = [ pkgs.tau-ai ];

  home.activation.ensureTauDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${tauDir}"
    chmod 700 "${tauDir}"
  '';
}
