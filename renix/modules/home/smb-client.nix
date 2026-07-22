{ pkgs, username, lib, ... }:
let
  homeDir = "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";
in
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    home.activation.ensureSmbCredentials = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      smb_dir="${dotfilesDir}/smb"
      credentials_file="$smb_dir/tnas01-masiero-personal.credentials"

      mkdir -p "$smb_dir"
      if [ ! -e "$credentials_file" ]; then
        cat > "$credentials_file" <<'EOF'
username=dmasiero
password=CHANGEME
# domain=WORKGROUP
EOF
      fi
      chmod 700 "$smb_dir" || true
      chmod 600 "$credentials_file" || true
    '';

    home.activation.linkSmbShortcuts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${homeDir}/downloads"
      ln -sfnT /mnt/smb/tnas01/masiero-personal "${homeDir}/vault"
      ln -sfnT "${homeDir}/vault/documents" "${homeDir}/documents"
      ln -sfnT "${homeDir}/vault/downloads/_ARCHIVED_" "${homeDir}/downloads/_ARCHIVED_"
      ln -sfnT "${homeDir}/vault/music" "${homeDir}/music"
      ln -sfnT "${homeDir}/vault/pictures" "${homeDir}/pictures"
      ln -sfnT "${homeDir}/vault/screenshots" "${homeDir}/screenshots"
      ln -sfnT "${homeDir}/vault/videos" "${homeDir}/videos"
      ln -sfnT /mnt/smb/tnas01/kvm-isos "${homeDir}/isos"
    '';


}
