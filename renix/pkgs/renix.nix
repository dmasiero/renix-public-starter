{ pkgs, ... }:

let
  runtimePath = pkgs.lib.makeBinPath (with pkgs; [
    coreutils
    curl
    findutils
    gawk
    gnugrep
    gnused
    git
    gzip
    nix
    perl
    python3
    gnutar
    util-linux
  ]);
  renix = pkgs.writeShellScriptBin "renix" ''
    export PATH=${runtimePath}:$PATH
    exec ${pkgs.bash}/bin/bash ${./renix}/renix.sh "$@"
  '';
in
{
  environment.systemPackages = [ renix ];
}
