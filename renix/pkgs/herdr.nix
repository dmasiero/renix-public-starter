{ lib, stdenv, fetchurl }:

let
  version = "0.7.5";

  asset =
    {
      x86_64-linux = "linux-x86_64";
      aarch64-linux = "linux-aarch64";
      x86_64-darwin = "macos-x86_64";
      aarch64-darwin = "macos-aarch64";
    }.${stdenv.hostPlatform.system} or (throw "herdr is not supported on ${stdenv.hostPlatform.system}");

  hash =
    {
      x86_64-linux = "sha256-PcgyiAc+TC08Z5ow576XvMqRQcb9F9u7khkULpXFklM=";
      aarch64-linux = "sha256-MudjoUmaa2lLHXCOTwYrdDvh2p80/PpNIS1ttv4JqLk=";
      x86_64-darwin = "sha256-P+UMSmPcgQIwaxMiF4Yo3bNlXNOuVteE8JQVNAjWnmI=";
      aarch64-darwin = "sha256-NzUFRrABJVWUO5Lq+WJmXeTiZDlbrrRCJ7gBXo/1sNY=";
    }.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "herdr";
  inherit version;

  src = fetchurl {
    url = "https://github.com/ogulcancelik/herdr/releases/download/v${version}/herdr-${asset}";
    inherit hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/herdr"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Terminal workspace manager for AI coding agents";
    homepage = "https://github.com/ogulcancelik/herdr";
    license = licenses.unfree;
    mainProgram = "herdr";
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
  };
}
