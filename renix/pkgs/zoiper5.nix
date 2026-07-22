{
  stdenv,
  lib,
  fetchurl,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  alsa-lib,
  at-spi2-atk,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk2,
  harfbuzz,
  krb5,
  libdrm,
  libnotify,
  libpulseaudio,
  libxkbcommon,
  libglvnd,
  mesa,
  nspr,
  nss,
  pango,
  v4l-utils,
  xorg,
  zlib,
  steam-run,
}:

stdenv.mkDerivation rec {
  pname = "zoiper5";
  version = "5.6.13";

  src = fetchurl {
    url = "https://www.zoiper.com/en/voip-softphone/download/zoiper5/for/linux";
    name = "Zoiper5_${version}_x86_64.tar.xz";
    hash = "sha256-D3IrWX2Y2h0my+HLJDRlyYn7H73xQaQ5JNxW+s4H/5c=";
    curlOptsList = [
      "--header"
      "Cookie: PHPSESSID="
      "--user-agent"
      "Mozilla"
    ];
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk2
    harfbuzz
    krb5
    libdrm
    libnotify
    libpulseaudio
    libxkbcommon
    libglvnd
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    v4l-utils
    xorg.libX11
    xorg.libXScrnSaver
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libxcb
    zlib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/zoiper5 $out/bin $out/share/pixmaps
    cp -R ./* $out/lib/zoiper5/
    chmod +x $out/lib/zoiper5/zoiper $out/lib/zoiper5/crashpad_handler

    cat > $out/bin/zoiper5 <<EOF
    #!${stdenv.shell}
    cd "$out/lib/zoiper5"
    export CHROME_DEVEL_SANDBOX=/run/wrappers/bin/__chromium-suid-sandbox
    cd "$out/lib/zoiper5"
    exec ${steam-run}/bin/steam-run "$out/lib/zoiper5/zoiper" "\$@"
    EOF
    chmod +x $out/bin/zoiper5
    ln -s zoiper5 $out/bin/zoiper

    cp $out/lib/zoiper5/Zoiper.ico $out/share/pixmaps/zoiper5.ico

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "zoiper5";
      desktopName = "Zoiper 5";
      comment = "SIP and IAX2 VoIP softphone";
      exec = "zoiper5 %U";
      icon = "zoiper5";
      terminal = false;
      categories = [ "Network" "Telephony" ];
      mimeTypes = [ "x-scheme-handler/sip" "x-scheme-handler/tel" ];
    })
  ];

  meta = with lib; {
    description = "SIP and IAX2 VoIP softphone";
    homepage = "https://www.zoiper.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "zoiper5";
  };
}
