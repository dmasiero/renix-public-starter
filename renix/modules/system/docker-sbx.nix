{ pkgs, username ? "doug", ... }:

{
  environment.systemPackages = [ pkgs.docker-sbx ];

  users.groups.docker-sbx = {};
  users.users.${username}.extraGroups = [ "docker-sbx" "kvm" ];

  services.udev.extraRules = ''
    KERNEL=="loop-control", GROUP="docker-sbx", MODE="0660"
    SUBSYSTEM=="block", KERNEL=="loop[0-9]*", GROUP="docker-sbx", MODE="0660"
  '';
}
