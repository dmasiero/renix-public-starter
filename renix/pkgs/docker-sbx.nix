{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, e2fsprogs, erofs-utils }:

stdenv.mkDerivation rec {
  pname = "docker-sbx";
  version = "0.35.0";

  src = fetchurl {
    url = "https://github.com/docker/sbx-releases/releases/download/v${version}/DockerSandboxes-linux-amd64.tar.gz";
    hash = "sha256-FG2q69lI8ru45GwxwTm3lTHJp4D5T5FaD8TKwuvPsFs=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec/lib
    install -m755 sbx $out/bin/sbx
    install -m755 containerd-shim-nerdbox-v1 $out/libexec/
    ln -s ${erofs-utils}/bin/mkfs.erofs $out/libexec/mkfs.erofs
    install -m644 nerdbox-kernel-* nerdbox-initrd-* $out/libexec/
    install -m755 libsailor.so $out/libexec/lib/libsailor.so

    wrapProgram $out/bin/sbx \
      --prefix PATH : "$out/libexec:${lib.makeBinPath [ e2fsprogs ]}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Isolated microVM sandboxes for AI coding agents";
    homepage = "https://docs.docker.com/ai/sandboxes/";
    license = licenses.unfree;
    mainProgram = "sbx";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
