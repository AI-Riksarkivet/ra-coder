{
  description = "Riksarkivet developer workspace toolsets (profiles: dev, datascience, ops)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true; # torch-bin bundles CUDA (NVIDIA EULA)
      };

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

      # Shared base for every profile.
      coreBase = pkgs: with pkgs; [
        git
        gh
        jq
        ripgrep
        fd
        starship
        uv
        opencode
      ];

      # Core = base + CPU ollama (the ml profile swaps in ollama-cuda instead)
      core = pkgs: coreBase pkgs ++ [ pkgs.ollama ];

      # Python package sets, composed per profile (one python env per profile -
      # two withPackages envs would collide in the same buildEnv).
      dsPythonPackages = ps: with ps; [
        numpy
        pandas
        polars
        pyarrow
        jupyterlab
      ];

      # Toolset profiles - edit to taste.
      profiles = pkgs: {
        dev = core pkgs ++ (with pkgs; [
          go
          nodejs_22
          gnumake
          gcc
          pkg-config
          kubectl
          kubernetes-helm
          (terraform-bin pkgs)
        ]);

        datascience = core pkgs ++ (with pkgs; [
          (python312.withPackages dsPythonPackages)
          nodejs_22
        ]);

        # ML = datascience + PyTorch with CUDA (official wheels via torch-bin;
        # torchWithCuda from nixpkgs would compile from source for hours)
        # + ollama-cuda for GPU-accelerated local models.
        # For GPU workspaces - CPU-only workspaces should use 'datascience'.
        ml = coreBase pkgs ++ (with pkgs; [
          ollama-cuda
          (python312.withPackages (ps: dsPythonPackages ps ++ [ ps.torch-bin ]))
          nodejs_22
        ]);

        # LLM = GPU-accelerated local models (ollama-cuda) without the ML
        # python stack - for workspaces whose main job is running a local LLM.
        llm = coreBase pkgs ++ (with pkgs; [
          ollama-cuda
          nodejs_22
        ]);

        ops = core pkgs ++ (with pkgs; [
          kubectl
          kubernetes-helm
          k9s
          argo-workflows
          kustomize
          kubectx
          awscli2
          azure-cli
          (terraform-bin pkgs)
        ]);
      };
    in
    {
      # Installable environments: `nix profile add <flake>#<profile>`
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          envs = builtins.mapAttrs
            (name: tools: pkgs.buildEnv {
              name  = "riksarkivet-${name}-env";
              paths = tools;
            })
            (profiles pkgs);
        in
        envs // { default = envs.dev; });

      # Alternative: ephemeral shells via `nix develop <flake>#<profile>`
      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          shells = builtins.mapAttrs
            (name: tools: pkgs.mkShell {
              name     = "riksarkivet-${name}";
              packages = tools;
            })
            (profiles pkgs);
        in
        shells // { default = shells.dev; });
    };
}
