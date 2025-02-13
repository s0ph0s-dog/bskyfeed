{
  description = "RSS feed generator for Bluesky accounts";

  # Nixpkgs / NixOS version to use.
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.11";
    cosmo = {
      url = "github:s0ph0s-dog/cosmopolitan/s0ph0s-patches";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, cosmo, nixpkgs }:
    let

      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = "1.0.0";

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ]; #"aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        bskyfeed = with final; stdenv.mkDerivation rec {
          pname = "bskyfeed";
          inherit version;

          src = ./.;

          nativeBuildInputs = [
            cosmo.defaultPackage.${pkgs.stdenv.hostPlatform.system}
            zip
            gnumake
          ];

          dontCheck = true;
          dontPatch = true;
          dontConfigure = true;
          dontFixup = true;

          buildPhase = ''
            runHook preBuild

            cp "${cosmo.defaultPackage.${pkgs.stdenv.hostPlatform.system}}/bin/redbean" ./redbean-3.0beta.com
            ls .
            make build

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            install bskyfeed.com $out/bin

            runHook postInstall
          '';
        };

      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) bskyfeed;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.bskyfeed);

      # A NixOS module, if applicable (e.g. if the package provides a system service).
      nixosModules.bskyfeed =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlay ];

          users.groups.bskyfeed = {};
          users.users.bskyfeed = {
            isSystemUser = true;
            group = "bskyfeed";
          };
          systemd.services.bskyfeed = {
            path = [ pkgs.bskyfeed ];
            script = "bskyfeed.com -l 127.0.0.1";
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "simple";
              User = "bskyfeed";
              WorkingDirectory = "/tmp/bskyfeed";
            };
          };
        };
    };
}
