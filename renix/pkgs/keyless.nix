{ lib, rustPlatform, fetchFromGitHub, pkg-config, perl, python3, makeWrapper, alsa-lib, xdotool, xorg, glib, gtk3, libsoup_3, webkitgtk_4_1, cudaPackages }:

rustPlatform.buildRustPackage rec {
  pname = "keyless";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "hate";
    repo = "keyless";
    rev = "tui-v${version}";
    hash = "sha256-0Ubc1PhDYT5L3Ap6JHVkpfTwEYD2ylzZjzVKW5qwS7A=";
  };

  cargoHash = "sha256-6G5teab9awQhBCmUx+FdZRRkutxZLCrVHgRfMt9T+R0=";
  cargoBuildFlags = [ "-p" "keyless" "--features" "cuda" ];

  nativeBuildInputs = [
    pkg-config
    perl
    python3
    makeWrapper
    cudaPackages.setupCudaHook
    cudaPackages.cuda_nvcc
  ];

  buildInputs = [
    alsa-lib
    xdotool
    xorg.libX11
    xorg.libXi
    xorg.libXtst
    xorg.libXrandr
    xorg.libXext
    xorg.libXrender
    xorg.libXfixes
    xorg.libXcomposite
    xorg.libXcursor
    glib
    gtk3
    libsoup_3
    webkitgtk_4_1
    cudaPackages.cuda_cudart
    cudaPackages.cuda_nvrtc
    cudaPackages.libcublas
    cudaPackages.libcurand
  ];

  # This repo targets a single RTX 5090 host, so we can compile Candle CUDA kernels
  # for the local GPU architecture directly instead of probing nvidia-smi in the sandbox.
  CUDA_ROOT = "${cudaPackages.cuda_cudart}";
  CUDA_COMPUTE_CAP = "120";

  postPatch = ''
    # TUI-only build: drop the desktop Tauri workspace member so we can package the CLI cleanly.
    perl -0pi -e 's#,\n\s*"keyless-desktop/src-tauri"##g' Cargo.toml

    # Linux audio workaround: do not force 48 kHz on CPAL/ALSA, prefer the device default config.
    python3 - <<'PY'
from pathlib import Path
p = Path('keyless-audio/src/input/cpal.rs')
text = p.read_text()
text = text.replace("""            } else {
                // Tier 2: No explicit rate; prefer 48 kHz for optimal quality.
                pick_48k()
            };""", """            } else {
                // Tier 2: No explicit rate; let the device default win on Linux.
                None
            };""")
text = text.replace("let pick_48k = || -> Option<cpal::SupportedStreamConfig> {", "let _pick_48k = || -> Option<cpal::SupportedStreamConfig> {")
text = text.replace("            let mut chosen = match selected {", "            let chosen = match selected {")
text = text.replace("""            if chosen.sample_rate().0 > 48_000
                && let Some(cfg48) = pick_48k()
            {
                chosen = cfg48;
            }""", "")
p.write_text(text)
PY
  '';

  postFixup = ''
    wrapProgram "$out/bin/keyless" \
      --prefix LD_LIBRARY_PATH : "${cudaPackages.cudatoolkit}/lib:/run/opengl-driver/lib:/run/opengl-driver-32/lib"
  '';

  meta = with lib; {
    description = "Privacy-first local speech-to-text dictation tool (TUI)";
    homepage = "https://github.com/hate/keyless";
    license = licenses.mit;
    mainProgram = "keyless";
    platforms = platforms.linux;
  };
}
