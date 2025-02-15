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

  outputs = {
    self,
    cosmo,
    nixpkgs,
  }: let
    # to work with older version of flakes
    lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

    # Generate a user-friendly version number.
    version = "1.0.0";

    # System types to support.
    supportedSystems = ["x86_64-linux" "x86_64-darwin"]; #"aarch64-linux" "aarch64-darwin" ];

    # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Nixpkgs instantiated for supported system types.
    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      });
  in {
    formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.alejandra;
    # A Nixpkgs overlay.
    overlays.default = final: prev: {
      bskyfeed = final.stdenv.mkDerivation rec {
        pname = "bskyfeed";
        inherit version;

        src = ./.;

        nativeBuildInputs = [
          cosmo.packages.${final.pkgs.stdenv.hostPlatform.system}.default
          final.zip
          final.gnumake
        ];

        dontCheck = true;
        dontPatch = true;
        dontConfigure = true;
        dontFixup = true;

        buildPhase = ''
          runHook preBuild

          cp "${cosmo.packages.${final.pkgs.stdenv.hostPlatform.system}.default}/bin/redbean" ./redbean-3.0beta.com
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
    packages = forAllSystems (system: {
      inherit (nixpkgsFor.${system}) bskyfeed;
      default = self.packages.${system}.bskyfeed;
    });

    # A NixOS module, if applicable (e.g. if the package provides a system service).
    nixosModules.bskyfeed = {
      lib,
      pkgs,
      config,
      ...
    }: let
      cfg = config.services.bskyfeed;
    in {
      imports = [cosmo.nixosModules.default];

      options.services.bskyfeed = {
        enable = lib.mkEnableOption "bskyfeed Bluesky RSS feed generator service";
        ports = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [8080];
          example = [80 443];
          description = "The port numbers that bskyfeed should listen on.";
        };

        enableNginxVhost = lib.mkEnableOption "nginx virtual host configuration for reverse-proxying bskyfeed (and doing TLS)";

        publicDomainName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          example = "bskyfeed.example.com";
          default = null;
          description = "The public hostname for the nginx virtual host and TLS certificates";
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
          nixpkgs.overlays = [self.overlays.default];

          users.groups.bskyfeed = {};
          users.users.bskyfeed = {
            isSystemUser = true;
            group = "bskyfeed";
          };
          systemd.tmpfiles.rules = [
            "d /tmp/bskyfeed bskyfeed bskyfeed"
          ];
          systemd.services.bskyfeed = {
            path = [pkgs.bskyfeed];
            script = let
              system = pkgs.stdenv.hostPlatform.system;
              ape = "${cosmo.packages.${system}.default}/bin/ape";
              bskyfeed = "${self.packages.${system}.default}/bin/bskyfeed.com";
              portString = toString (map (port: "-p ${toString port}") cfg.ports);
            in "${ape} ${bskyfeed} -l 127.0.0.1 ${portString}";
            wantedBy = ["multi-user.target"];
            serviceConfig = {
              Type = "simple";
              User = "bskyfeed";
              WorkingDirectory = "/tmp/bskyfeed";
            };
          };
        })
        (lib.mkIf (cfg.enable && cfg.enableNginxVhost) {
          assertions = [
            {
              assertion = cfg.publicDomainName != null;
              message = "if enableNginxVhost is set, you must provide publicDomainName";
            }
          ];
          services.nginx.virtualHosts.${cfg.publicDomainName} = {
            forceSSL = true;
            enableACME = true;
            locations."/" = {
              proxyPass = let
                port = toString (builtins.head cfg.ports);
              in "http://127.0.0.1:${port}";
              recommendedProxySettings = true;
              extraConfig = ''
                proxy_http_version 1.1;
                proxy_buffering off;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "Upgrade";
              '';
            };
          };
        })
      ];
    };
  };
}
