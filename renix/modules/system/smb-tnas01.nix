{ lib, pkgs, username ? "doug", ... }:

let
  homeDir = "/home/${username}";
  dotfilesDir = "${homeDir}/dotfiles";
  host = "tnas01.masiero.internal";
  reachableMarker = "/run/smb-reachable/tnas01";
  baseOptions = [
    "credentials=${dotfilesDir}/smb/tnas01-masiero-personal.credentials"
    "uid=${username}"
    "gid=users"
    "file_mode=0660"
    "dir_mode=0770"
    "iocharset=utf8"
    "vers=3.1.1"
    "soft"
    "echo_interval=15"
    "actimeo=30"
  ];
  shares = [
    {
      name = "masiero-personal";
      where = "/mnt/smb/tnas01/masiero-personal";
      extraOptions = [ "mfsymlinks" ];
    }
    {
      name = "kvm-isos";
      where = "/mnt/smb/tnas01/kvm-isos";
      extraOptions = [ ];
    }
    {
      name = "joy-personal";
      where = "/mnt/smb/tnas01/joy-personal";
      extraOptions = [ ];
    }
  ];
  mounts = map (share: {
    what = "//${host}/${share.name}";
    where = share.where;
    type = "cifs";
    options = lib.concatStringsSep "," (baseOptions ++ share.extraOptions);
    unitConfig = {
      ConditionPathExists = reachableMarker;
      X-StopOnReconfiguration = false;
    };
    mountConfig.TimeoutSec = "5s";
  }) shares;
  automounts = map (share: {
    where = share.where;
    wantedBy = [ "multi-user.target" ];
    unitConfig.X-StopOnReconfiguration = false;
    automountConfig.TimeoutIdleSec = "60s";
  }) shares;
in
{
  boot.supportedFilesystems = [ "cifs" ];
  environment.systemPackages = [ pkgs.cifs-utils ];

  systemd.tmpfiles.rules = [
    "d /run/smb-reachable 0755 root root -"
  ];

  systemd.services.smb-tnas01-reachable = {
    description = "Check whether tnas01 SMB is reachable";
    serviceConfig.Type = "oneshot";
    path = [ pkgs.coreutils pkgs.getent pkgs.netcat-openbsd ];
    script = ''
      marker=${reachableMarker}
      mkdir -p "$(dirname "$marker")"
      if getent ahostsv4 ${host} >/dev/null 2>&1 && nc -z -w2 ${host} 445 >/dev/null 2>&1; then
        touch "$marker"
      else
        rm -f "$marker"
      fi
    '';
  };

  systemd.timers.smb-tnas01-reachable = {
    description = "Periodically check whether tnas01 SMB is reachable";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10s";
      OnUnitActiveSec = "30s";
      AccuracySec = "5s";
      Unit = "smb-tnas01-reachable.service";
    };
  };

  systemd.mounts = mounts;
  systemd.automounts = automounts;

  system.activationScripts.resetOptionalSmbMountFailures = ''
    ${pkgs.systemd}/bin/systemctl reset-failed \
      'mnt-smb-tnas01-masiero\x2dpersonal.mount' \
      'mnt-smb-tnas01-kvm\x2disos.mount' \
      'mnt-smb-tnas01-joy\x2dpersonal.mount' \
      2>/dev/null || true
  '';
}
