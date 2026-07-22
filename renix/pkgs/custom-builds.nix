# Keep entries sorted alphabetically by displayName/id for readable renix output.
[
  {
    id = "cliamp";
    displayName = "cliamp";
    attrName = "cliamp";
    systems = [ "x86_64-linux" ];
    source = {
      type = "github-release";
      owner = "bjarneo";
      repo = "cliamp";
      stripV = true;
    };
    update = {
      type = "fetchurl-template";
      target = "pkgs/cliamp.nix";
      urlTemplate = "https://github.com/bjarneo/cliamp/releases/download/v{version}/cliamp-linux-amd64";
    };
  }
  {
    id = "docker-sbx";
    displayName = "docker-sbx";
    attrName = "docker-sbx";
    systems = [ "x86_64-linux" ];
    source = {
      type = "github-release";
      owner = "docker";
      repo = "sbx-releases";
      stripV = true;
    };
    update = {
      type = "fetchurl-template";
      target = "pkgs/docker-sbx.nix";
      urlTemplate = "https://github.com/docker/sbx-releases/releases/download/v{version}/DockerSandboxes-linux-amd64.tar.gz";
    };
  }
  {
    id = "herdr";
    displayName = "herdr";
    attrName = "herdr";
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    source = {
      type = "github-release";
      owner = "ogulcancelik";
      repo = "herdr";
      stripV = true;
    };
    update = {
      type = "fetchurl-template-system-assets";
      target = "pkgs/herdr.nix";
      urlTemplate = "https://github.com/ogulcancelik/herdr/releases/download/v{version}/herdr-{asset}";
      systemAssets = {
        x86_64-linux = "linux-x86_64";
        aarch64-linux = "linux-aarch64";
        x86_64-darwin = "macos-x86_64";
        aarch64-darwin = "macos-aarch64";
      };
    };
  }
  {
    id = "pi-coding-agent";
    displayName = "pi-coding-agent";
    attrName = "pi-coding-agent";
    source = {
      type = "github-release";
      owner = "earendil-works";
      repo = "pi";
      stripV = true;
    };
    update = {
      type = "github-release-system-assets";
      target = "pkgs/pi-coding-agent.nix";
      urlTemplate = "https://github.com/earendil-works/pi/releases/download/v{version}/pi-{asset}.tar.gz";
    };
  }
  {
    id = "tau-ai";
    displayName = "tau-ai";
    attrName = "tau-ai";
    source = {
      type = "pypi";
      package = "tau-ai";
    };
    update = {
      type = "pypi";
      target = "pkgs/tau-ai.nix";
    };
  }
]
