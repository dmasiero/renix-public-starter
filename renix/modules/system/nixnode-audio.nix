{ pkgs, ... }:

let
  patchedAlsaUcm2 = pkgs.runCommand "alsa-ucm2-nixnode-cs42l45" { } ''
    src=${pkgs.alsa-lib}/share/alsa/ucm2
    dst=$out/share/alsa/ucm2
    mkdir -p $dst/sof-soundwire

    for entry in "$src"/*; do
      name=$(basename "$entry")
      if [ "$name" != sof-soundwire ]; then
        ln -s "$entry" "$dst/$name"
      fi
    done

    for entry in "$src"/sof-soundwire/*; do
      ln -s "$entry" "$dst/sof-soundwire/$(basename "$entry")"
    done

    cat > $dst/sof-soundwire/cs42l45-dmic.conf <<'EOF'
SectionDevice."Mic" {
	Comment "Internal Microphones"

	EnableSequence [
		cset "name='cs42l45 IT 11 Switch' on"
		cset "name='cs42l45 IT 31 Microphone Switch' on"
		cset "name='cs42l45 IT 32 LineIn Stereo Switch' on"
		cset "name='cs42l45 IT 33 Headset Switch' on"
		cset "name='cs42l45 FU 36 Channel Switch' on,on"
		cset "name='cs42l45 FU 113 Channel Switch' on,on"
		cset "name='Microphone Capture TDFB beam switch' on"
		cset "name='Microphone Capture DRC switch' on"
		cset "name='cs42l45 MU 35 Mixer 1' on"
		cset "name='cs42l45 MU 35 Mixer 2' on"
	]

	Value {
		CapturePriority 100
		CapturePCM "hw:''${CardId},4"
	}
}
EOF

    cat > $dst/sof-soundwire/cs42l45.conf <<'EOF'
SectionDevice."Headphones" {
	Comment "Headphones"

	EnableSequence [
		cset "name='cs42l45 OT 43 Headphone Switch' on"
		cset "name='cs42l45 FU 14 Channel Switch' on,on"
		cset "name='cs42l45 FU 41 Channel Switch' on,on"
	]

	DisableSequence [
		cset "name='cs42l45 OT 43 Headphone Switch' off"
	]

	Value {
		PlaybackPriority 200
		PlaybackPCM "hw:''${CardId},0"
		PlaybackVolume "Post Mixer Jack Out Playback Volume"
		JackControl "cs42l45 OT 43 Headphone Jack"
	}
}

SectionDevice."Headset" {
	Comment "Headset Microphone"

	Value {
		CapturePriority 200
		CapturePCM "hw:''${CardId},1"
		JackControl "cs42l45 IT 31 Microphone Jack"
	}
}
EOF
  '';
in
{
  boot.kernelParams = [ "snd_intel_dspcfg.dsp_driver=3" ];

  systemd.services.nixnode-audio-init = {
    description = "Initialize nixnode ThinkPad cs42l45 microphone path";
    wantedBy = [ "multi-user.target" ];
    after = [ "sound.target" "systemd-udev-settle.service" ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.alsa-utils ];
    script = ''
      amixer -c 0 cset name='cs42l45 IT 11 Switch' on || true
      amixer -c 0 cset name='cs42l45 IT 31 Microphone Switch' on || true
      amixer -c 0 cset name='cs42l45 IT 32 LineIn Stereo Switch' on || true
      amixer -c 0 cset name='cs42l45 IT 33 Headset Switch' on || true
      amixer -c 0 cset name='cs42l45 FU 36 Channel Switch' on,on || true
      amixer -c 0 cset name='cs42l45 FU 113 Channel Switch' on,on || true
      amixer -c 0 cset name='cs42l45 FU 14 Channel Switch' on,on || true
      amixer -c 0 cset name='cs42l45 FU 41 Channel Switch' on,on || true
      amixer -c 0 cset name='Microphone Capture TDFB beam switch' on || true
      amixer -c 0 cset name='Microphone Capture DRC switch' on || true
      amixer -c 0 cset name='cs42l45 MU 35 Mixer 1' on || true
      amixer -c 0 cset name='cs42l45 MU 35 Mixer 2' on || true
    '';
  };

  systemd.user.services = {
    pipewire.environment.ALSA_CONFIG_UCM2 = "${patchedAlsaUcm2}/share/alsa/ucm2";
    wireplumber.environment.ALSA_CONFIG_UCM2 = "${patchedAlsaUcm2}/share/alsa/ucm2";
  };

  # Prefer the UCM HiFi profile on this SoundWire card. Nixpkgs 25.11's ALSA
  # UCM set is missing the cs42l45 files needed by this ThinkPad.
  services.pipewire.wireplumber.extraConfig."10-nixnode-audio-profile" = {
    "wireplumber.settings" = {
      "device.restore-profile" = false;
      "device.restore-routes" = false;
    };
    "device.profile.priority.rules" = [
      {
        matches = [
          { "device.name" = "alsa_card.pci-0000_00_1f.3-platform-sof_sdw"; }
        ];
        actions.update-props.priorities = [ "HiFi" "pro-audio" ];
      }
    ];
  };
}
