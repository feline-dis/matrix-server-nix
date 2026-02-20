{
  description = "NixOS configuration for the ohana-matrix.xyz homeserver";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    feline-matrix = {
      url = "github:feline-dis/feline-matrix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    matrix-claude-bot = {
      url = "github:feline-dis/matrix-claude-bot";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, feline-matrix, matrix-claude-bot, sops-nix, disko, deploy-rs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.ohana = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit feline-matrix matrix-claude-bot sops-nix disko;
        };
        modules = [
          sops-nix.nixosModules.sops
          disko.nixosModules.disko
          ./hosts/ohana
        ];
      };

      deploy.nodes.ohana = {
        hostname = "ohana-matrix.xyz";
        sshUser = "root";
        profiles.system = {
          path = deploy-rs.lib.${system}.activate.nixos
            self.nixosConfigurations.ohana;
        };
        magicRollback = false;
      };

      checks = builtins.mapAttrs
        (system: deployLib: deployLib.deployChecks self.deploy)
        deploy-rs.lib;

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          deploy-rs.packages.${system}.default
          pkgs.sops
          pkgs.age
          pkgs.ssh-to-age
        ];
      };
    };
}
