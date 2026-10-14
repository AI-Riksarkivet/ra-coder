{
  description = "Riksarkivet developer workspace toolset";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };

      # Terraform from the official pinned binary. The nixpkgs build is
      # unfree (BUSL-1.1) and therefore NOT in cache.nixos.org - every
      # workspace would compile it from source (~15 min) on first boot.
      terraform-bin = pkgs:
        let
          version = "1.16.5";
          arch = if pkgs.stdenv.hostPlatform.isAarch64 then {
            name = "arm64";
            hash = "sha256-YaULAEhe5IEM8gWB7wgPxU001mbhdcWNmhBQHGXBzN4=";
          } else {
            name = "amd64";
            hash = "sha256-K8L8//AzJlyeAsoDUfAXlOsSL2KpsqSaMpS55J6qteQ=";
          };
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "terraform-bin";
          inherit version;
          src = pkgs.fetchurl {
            url = "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_${arch.name}.zip";
            sha256 = arch.hash;
          };
          nativeBuildInputs = [ pkgs.unzip ];
          unpackPhase = "unzip $src";
          installPhase = ''
            mkdir -p $out/bin
            install -m755 terraform $out/bin/terraform
          '';
        };

      # The workspace toolset - edit to taste.
      toolset = pkgs: with pkgs; [
        # Git & VCS
        git
        gh

        # Kubernetes & infra
        kubectl
        kubernetes-helm
        k9s
        argo-workflows
        (terraform-bin pkgs)

        # Languages & package managers
        python312
        uv
        nodejs_22
        go

        # Build tools
        gnumake
        gcc
        pkg-config

        # Shell & utilities
        starship
        jq
        ripgrep
        fd

        # Cloud CLIs
        awscli2
        azure-cli
      ];
    in
    {
      # Installable environment: `nix profile install <this flake>`
      packages = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          default = pkgs.buildEnv {
            name  = "riksarkivet-dev-env";
            paths = toolset pkgs;
          };
        });

      # Alternative: ephemeral shell via `nix develop <this flake>`
      devShells = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          default = pkgs.mkShell {
            name     = "riksarkivet-dev";
            packages = toolset pkgs;
          };
        });
    };
}
