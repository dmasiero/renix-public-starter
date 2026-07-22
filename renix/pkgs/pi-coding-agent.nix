{ lib, stdenv, fetchurl, autoPatchelfHook }:

let
  system = stdenv.hostPlatform.system;
  platform =
    {
      x86_64-linux = {
        asset = "linux-x64";
        hash = "sha256-H24j2ewGaKE86px4bj1Uwfxnm44i5/a/reA0n0gHy/I=";
      };
      aarch64-linux = {
        asset = "linux-arm64";
        hash = "sha256-wEnhMshUZiJNV9GfeSSQmwwP28m+2OCR3cNhgwcEs5I=";
      };
      x86_64-darwin = {
        asset = "darwin-x64";
        hash = "sha256-7K7Q7w/K7/LkdSlPw0stfeRwBDSrnfI82w//2c+t9bg=";
      };
      aarch64-darwin = {
        asset = "darwin-arm64";
        hash = "sha256-okg0AZ7ALuWkdf8cWl6fg4l0GRumrcQ0j25kdafHZns=";
      };
    }.${system} or (throw "pi-coding-agent: unsupported system ${system}");
in
stdenv.mkDerivation rec {
  pname = "pi-coding-agent";
  version = "0.81.1";

  src = fetchurl {
    url = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-${platform.asset}.tar.gz";
    hash = platform.hash;
  };

  sourceRoot = "pi";

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/pi-coding-agent
    cp -R . $out/share/pi-coding-agent/
    ln -s $out/share/pi-coding-agent/pi $out/bin/pi

    runHook postInstall
  '';

  meta = with lib; {
    description = "Interactive coding agent CLI with read, bash, edit, write tools";
    homepage = "https://github.com/earendil-works/pi";
    license = licenses.mit;
    mainProgram = "pi";
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
  };
}
