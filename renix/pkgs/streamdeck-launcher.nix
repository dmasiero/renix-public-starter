{ lib, python3Packages, writeShellApplication }:

let
  python = python3Packages.python.withPackages (_: [
    python3Packages.cairosvg
    python3Packages.pillow
    python3Packages.streamdeck
  ]);
in
writeShellApplication {
  name = "streamdeck-launcher";
  text = ''
    exec ${python}/bin/python3 ${./streamdeck-launcher.py}
  '';
  meta = {
    description = "Stream Deck launcher";
    mainProgram = "streamdeck-launcher";
    platforms = lib.platforms.linux;
  };
}
