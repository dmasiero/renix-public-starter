{
  stdenv,
  lib,
  fetchurl,
  autoPatchelfHook,
  wrapQtAppsHook,
  cups,
  freetype,
  libGL,
  libxkbcommon,
  pkcs11helper,
  sane-backends,
  zlib,
  qtbase,
  qt5compat,
  qtdeclarative,
  qtsvg,
}:

stdenv.mkDerivation rec {
  pname = "masterpdf";
  version = "5.9.98";

  src = fetchurl {
    url = "https://code-industry.net/public/master-pdf-editor-${version}-1-qt6.x86_64.tar.gz";
    hash = "sha256-huaHIE4M6fK9DQY7ehwkYxILpJKw9GU3LjbhCikst88=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapQtAppsHook
  ];

  buildInputs = [
    cups
    freetype
    libGL
    libxkbcommon
    pkcs11helper
    sane-backends
    stdenv.cc.cc.lib
    zlib
    qtbase
    qt5compat
    qtdeclarative
    qtsvg
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/masterpdf $out/bin $out/share/applications
    cp -R ./* $out/lib/masterpdf/

    ln -s $out/lib/masterpdf/masterpdfeditor5 $out/bin/masterpdfeditor5
    ln -s masterpdfeditor5 $out/bin/masterpdf

    cp usr/share/applications/net.code-industry.masterpdfeditor5.desktop $out/share/applications/
    substituteInPlace $out/share/applications/net.code-industry.masterpdfeditor5.desktop \
      --replace-fail 'Exec=/opt/master-pdf-editor-5/masterpdfeditor5' 'Exec=masterpdfeditor5' \
      --replace-fail 'Path=/opt/master-pdf-editor-5' 'Path=${placeholder "out"}/lib/masterpdf' \
      --replace-fail 'Icon=/opt/master-pdf-editor-5/masterpdfeditor5.png' 'Icon=masterpdfeditor5'

    cp -R usr/share/icons $out/share/

    runHook postInstall
  '';

  meta = with lib; {
    description = "PDF editor for viewing, creating, and modifying PDF documents";
    homepage = "https://code-industry.net/free-pdf-editor/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    mainProgram = "masterpdf";
  };
}
