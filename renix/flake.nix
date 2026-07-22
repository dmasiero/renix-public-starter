{
  description = "Multi-host NixOS + Home Manager config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Public fixtures keep forks evaluable without access to private infrastructure.
    # Replace or remove these inputs when adapting Renix to your own environment.
    dotfilesCerts = {
      url = "path:./fixtures/certs";
      flake = false;
    };
    graylogCli = {
      url = "path:./fixtures/graylog-cli";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nix-darwin, dotfilesCerts, graylogCli, ... }:
    let
      username = "doug";

      mkHost = hostGroup: hostName: system: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit dotfilesCerts graylogCli username;
        };
        modules = [
          ./hosts/${hostGroup}/${hostName}/default.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = import ./hosts/${hostGroup}/${hostName}/home.nix;
            home-manager.extraSpecialArgs = {
              inherit username;
            };
          }
        ];
      };

      mkDarwinHost = hostName: system: nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = {
          inherit self graylogCli username;
        };
        modules = [
          ./hosts/${system}/${hostName}/default.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = import ./hosts/${system}/${hostName}/home.nix;
            home-manager.extraSpecialArgs = {
              inherit username;
            };
          }
        ];
      };
    in {
      nixosConfigurations = {
        demo = mkHost "x86_64-linux" "demo" "x86_64-linux";
        nextgate = mkHost "x86_64-linux" "nextgate" "x86_64-linux";
        coregate = mkHost "x86_64-linux" "coregate" "x86_64-linux";
        nixnode = mkHost "x86_64-linux" "nixnode" "x86_64-linux";
        pomace = mkHost "aarch64-linux" "pomace" "aarch64-linux";
      };

      darwinConfigurations = {
        macvm = mkDarwinHost "macvm" "aarch64-darwin";
      };
    };
}
