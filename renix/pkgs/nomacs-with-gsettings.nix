{ glib, gsettings-desktop-schemas, gtk3, makeWrapper, nomacs, runCommand, symlinkJoin }:

let
  schemas = runCommand "nomacs-gsettings-schemas" {
    nativeBuildInputs = [ glib.dev ];
  } ''
    mkdir -p $out/share/glib-2.0/schemas
    cp ${gsettings-desktop-schemas}/share/gsettings-schemas/*/glib-2.0/schemas/*.xml $out/share/glib-2.0/schemas/
    cp ${gtk3}/share/gsettings-schemas/*/glib-2.0/schemas/*.xml $out/share/glib-2.0/schemas/
    glib-compile-schemas $out/share/glib-2.0/schemas
  '';
in
symlinkJoin {
  name = "nomacs-with-gsettings";
  paths = [ nomacs ];
  buildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/nomacs \
      --set GSETTINGS_SCHEMA_DIR ${schemas}/share/glib-2.0/schemas
  '';
}
