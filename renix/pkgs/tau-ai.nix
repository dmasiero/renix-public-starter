{ lib, stdenvNoCC, fetchurl, makeWrapper, python314, uv }:

stdenvNoCC.mkDerivation rec {
  pname = "tau-ai";
  version = "0.2.3";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/78/20/6910258ac3baf71ce0e26894c95e5709f05c0d5a6e981f16fbe790f76d3f/tau_ai-0.2.3-py3-none-any.whl";
    hash = "sha256-ofvdM35ZuRNMLLd09qzYeWKYcFj8FlcxoOn73Lec7IE=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/tau-ai
    cp $src $out/share/tau-ai/tau-ai-${version}.whl

    makeWrapper ${uv}/bin/uv $out/bin/tau \
      --add-flags "tool run --python ${python314}/bin/python3.14 --from tau-ai==${version} tau"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Agentic coding tool";
    homepage = "https://twotimespi.dev/";
    license = licenses.mit;
    mainProgram = "tau";
    platforms = platforms.unix;
  };
}
