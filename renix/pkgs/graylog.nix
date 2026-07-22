{ lib, stdenvNoCC, graylogSource }:

stdenvNoCC.mkDerivation {
  pname = "graylog";
  version = "0.2.0";

  src = graylogSource;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 cli/graylog "$out/bin/graylog"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Masiero Graylog CLI from the production Graylog repository";
    homepage = "https://gitea.masiero.internal/masiero/graylog";
    license = licenses.unfree;
    mainProgram = "graylog";
    platforms = platforms.unix;
  };
}
