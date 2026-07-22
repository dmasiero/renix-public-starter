{ lib
, buildGoModule
, fetchFromGitHub
, libX11
, stdenv
}:

buildGoModule rec {
  pname = "tart-guest-agent";
  version = "2026-03-23-30fe76c";

  src = fetchFromGitHub {
    owner = "cirruslabs";
    repo = "tart-guest-agent";
    rev = "30fe76ca7c7d9cc77421989a79c7d300a951fd2c";
    hash = "sha256-9blNdXHZ+CNdmiu7vIJ93SL8nZq/LRI6b9IdYcP8hG4=";
  };

  vendorHash = "sha256-1BMc7057eW/WawpIrh1g8mP2/u6XBX+wPB/Q7pucvUg=";

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ libX11 ];

  # Linux Tart guests expose the SPICE virtio serial channel here. Upstream's
  # agent targets macOS guests and uses /dev/tty.com.redhat.spice.0.
  postPatch = ''
    substituteInPlace internal/spice/vdagent/vdagent.go \
      --replace-fail '/dev/tty.com.redhat.spice.0' '/dev/virtio-ports/com.redhat.spice.0'

    # Upstream opens the SPICE virtio port before initializing the clipboard.
    # If the graphical clipboard is not ready yet, that failure leaks the open
    # port fd and every retry gets EBUSY. Initialize clipboard first instead.
    substituteInPlace internal/spice/vdagent/vdagent.go \
      --replace-fail 'sp, err := os.OpenFile(serialPortPath, os.O_RDWR, 0)
	if err != nil {
		return nil, err
	}

	if err := clipboard.Init(); err != nil {
		return nil, err
	}' 'if err := clipboard.Init(); err != nil {
		return nil, err
	}

	sp, err := os.OpenFile(serialPortPath, os.O_RDWR, 0)
	if err != nil {
		return nil, err
	}'
  '';

  # The clipboard dependency dlopen(3)s libX11 by soname, so point it at the
  # Nix store path after buildGoModule has unpacked vendored dependencies.
  preBuild = ''
    if [ -e vendor/golang.design/x/clipboard/clipboard_linux.c ]; then
      substituteInPlace vendor/golang.design/x/clipboard/clipboard_linux.c \
        --replace-fail 'dlopen("libX11.so", RTLD_LAZY)' 'dlopen("${lib.getLib libX11}/lib/libX11.so", RTLD_LAZY)'
    fi
  '';

  postInstall = ''
    mv $out/bin/cmd $out/bin/tart-guest-agent
  '';

  meta = {
    description = "Guest agent for Tart VMs";
    homepage = "https://github.com/cirruslabs/tart-guest-agent";
    license = lib.licenses.asl20;
    mainProgram = "tart-guest-agent";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
