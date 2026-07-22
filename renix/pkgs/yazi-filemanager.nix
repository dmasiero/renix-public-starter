{ lib, python3Packages, writeShellApplication, homeDir, dotfilesDir }:

let
  python = python3Packages.python.withPackages (_: [ python3Packages.dbus-next ]);
in
writeShellApplication {
  name = "yazi-filemanager";
  text = ''
    export YAZI_XDG=${lib.escapeShellArg "${dotfilesDir}/bin/xdg-yazi"}
    export YAZI_DEFAULT_URI=${lib.escapeShellArg "file://${homeDir}/downloads"}
    exec ${python}/bin/python3 ${./yazi-filemanager.py}
  '';
  meta = {
    description = "D-Bus FileManager1 bridge for opening folders in Yazi";
    mainProgram = "yazi-filemanager";
    platforms = lib.platforms.linux;
  };
}
