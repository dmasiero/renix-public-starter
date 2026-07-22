{ lib, stdenvNoCC, fetchurl, autoPatchelfHook, makeWrapper, alsa-lib, ffmpeg, pulseaudio, yt-dlp }:

stdenvNoCC.mkDerivation rec {
  pname = "cliamp";
  version = "1.61.0";

  src = fetchurl {
    url = "https://github.com/bjarneo/cliamp/releases/download/v${version}/cliamp-linux-amd64";
    hash = "sha256-dENTNBotRE7Dc0BXhnUrQvkSxvaDLM5MEASAwjVbx0M=";
  };

  dontUnpack = true;
  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [ alsa-lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/cliamp"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/cliamp" \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg pulseaudio yt-dlp ]}
  '';

  meta = with lib; {
    description = "Retro terminal music player inspired by Winamp";
    homepage = "https://github.com/bjarneo/cliamp";
    license = licenses.mit;
    mainProgram = "cliamp";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
