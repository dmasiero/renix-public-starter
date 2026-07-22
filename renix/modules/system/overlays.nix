{ pkgs, lib, graylogCli ? null, ... }:

{
  nixpkgs.overlays = [
    (self: super:
      {
        pi-coding-agent = super.callPackage ../../pkgs/pi-coding-agent.nix {};
        tau-ai = super.callPackage ../../pkgs/tau-ai.nix {};
        tart-guest-agent = super.callPackage ../../pkgs/tart-guest-agent.nix {};
        keyless = super.callPackage ../../pkgs/keyless.nix {};
        herdr = super.callPackage ../../pkgs/herdr.nix {};
        graylog = super.callPackage ../../pkgs/graylog.nix {
          graylogSource = graylogCli;
        };
        tsshd = super.buildGoModule rec {
          pname = "tsshd";
          version = "0.1.6";
          src = super.fetchFromGitHub {
            owner = "trzsz";
            repo = "tsshd";
            rev = "v${version}";
            hash = "sha256-B5PTiz9luBxkDA9UMSkGYTcPbnXdL43rkFvbOUS5F6w=";
          };
          vendorHash = "sha256-dW05EoAVLqmiPRRG0R4KwKsSijZuxSe15iHkyCImtZY=";
          ldflags = [ "-s" "-w" ];
          meta = with super.lib; {
            description = "UDP server for trzsz-ssh (tssh) supporting connection migration and roaming";
            homepage = "https://github.com/trzsz/tsshd";
            license = licenses.mit;
            mainProgram = "tsshd";
          };
        };
      }
      // lib.optionalAttrs (super.stdenv.hostPlatform.isLinux && super.stdenv.hostPlatform.isx86_64) {
        docker-sbx = super.callPackage ../../pkgs/docker-sbx.nix {};
        bun = super.bun.overrideAttrs (old: rec {
          version = "1.3.11";
          src = super.fetchurl {
            url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64.zip";
            hash = "sha256-hhG6k1r4hvBabzh0ChUWAybBXl1dB63vlmEwtEk2B+0=";
          };
        });
      }
      // lib.optionalAttrs super.stdenv.hostPlatform.isLinux {
        cliamp = super.callPackage ../../pkgs/cliamp.nix {};
        masterpdf = super.qt6.callPackage ../../pkgs/masterpdf.nix {};
        nomacs-with-gsettings = super.callPackage ../../pkgs/nomacs-with-gsettings.nix {};
        flameshot = super.flameshot.overrideAttrs (old: rec {
          # PR #4498 fixes fractional-scale/multi-monitor capture geometry by
          # moving Linux capture to xdg-desktop-portal instead of the grim adapter.
          # Drop once nixpkgs has a Flameshot release containing this merge.
          version = "13.3.0-pr4498";
          src = super.fetchFromGitHub {
            owner = "flameshot-org";
            repo = "flameshot";
            rev = "53d4da8fcd0e00b755b3329674b756d9777d3a89";
            hash = "sha256-uBhu8y78/+80mnkKZjf9ArjycTGx4lPa9LZ2cc7VWFo=";
          };
          patches = [];
          nativeBuildInputs = old.nativeBuildInputs ++ [ super.python3 ];
          postPatch = (old.postPatch or "") + ''
            python3 - <<'PY'
from pathlib import Path
p = Path('CMakeLists.txt')
s = p.read_text()
start = s.index('# Dependency can be fetched via flatpak builder')
end = s.index('# This can be read from', start)
s = s[:start] + 'find_package(QtColorWidgets REQUIRED)\n\n' + s[end:]
p.write_text(s)
PY
          '';
        });
        galculator = super.galculator.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace src/ui.c \
              --replace-fail 'GtkListStore		*paper_store;
	GtkTreeSelection	*select;' 'GtkListStore		*paper_store;
	PangoFontDescription	*paper_font;
	GtkTreeSelection	*select;' \
              --replace-fail 'view_xml = paper_view_xml;
	
	/* markup / xalign / foreground */' 'view_xml = paper_view_xml;

	paper_font = pango_font_description_from_string ("Sans 48");
	gtk_widget_override_font (GTK_WIDGET(gtk_builder_get_object (view_xml, "paper_entry")), paper_font);
	pango_font_description_free (paper_font);
	
	/* markup / xalign / foreground */' \
              --replace-fail 'gtk_tree_view_set_model ((GtkTreeView *) tree_view, GTK_TREE_MODEL (paper_store));
	
	renderer = gtk_cell_renderer_text_new ();' 'gtk_tree_view_set_model ((GtkTreeView *) tree_view, GTK_TREE_MODEL (paper_store));
	
	renderer = gtk_cell_renderer_text_new ();
	g_object_set (renderer, "font", "Sans 48", NULL);'
          '';
        });
        zoiper5 = super.callPackage ../../pkgs/zoiper5.nix {};
      })
  ];
}
