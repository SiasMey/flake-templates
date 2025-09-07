{
  description = "Python project based on UV";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Core pyproject-nix ecosystem tools
    pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
    uv2nix.url = "github:pyproject-nix/uv2nix";
    pyproject-build-systems.url = "github:pyproject-nix/build-system-pkgs";

    # Ensure consistent dependencies between these tools
    pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs";
    pyproject-build-systems.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.inputs.pyproject-nix.follows = "pyproject-nix";
    pyproject-build-systems.inputs.pyproject-nix.follows = "pyproject-nix";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    uv2nix,
    pyproject-nix,
    pyproject-build-systems,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        inherit (nixpkgs) lib;
        pkgs = import nixpkgs {inherit system;};
        python = pkgs.python313;

        # 1. Load Project Workspace (parses pyproject.toml, uv.lock)
        workspace = uv2nix.lib.workspace.loadWorkspace {
          workspaceRoot = ./.; # Root of your flake/project
        };

        # 2. Generate Nix Overlay from uv.lock (via workspace)
        uvLockedOverlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel"; # Or "sdist"
        };

        # 3. Placeholder for Your Custom Package Overrides
        projectCustomOverrides = final: prev: {
          /*
          e.g., some-package = prev.some-package.overridePythonAttrs (...);
          */
        };

        # 4. Construct the Final Python Package Set
        pythonSet = (pkgs.callPackage pyproject-nix.build.packages {inherit python;})
          .overrideScope (nixpkgs.lib.composeManyExtensions [
          pyproject-build-systems.overlays.default # For build tools
          uvLockedOverlay # Your locked dependencies
          projectCustomOverrides # Your fixes
        ]);

        # --- This is where your project's metadata is accessed ---
        projectNameInToml = throw "name-of-project";
        thisProjectAsNixPkg = pythonSet.${projectNameInToml};

        # 5. Create the Python Runtime Environment
        appPythonEnv =
          pythonSet.mkVirtualEnv
          (thisProjectAsNixPkg.pname + "-env")
          workspace.deps.default; # Uses deps from pyproject.toml [project.dependencies]
      in {
        # Development Shell
        devShells.default = pkgs.mkShell {
          packages = [appPythonEnv pkgs.uv pkgs.zlib];
          shellHook = ''/* Your custom shell hooks */ '';
          env =
            {}
            // lib.optionalAttrs pkgs.stdenv.isLinux {
              LD_LIBRARY_PATH = lib.makeLibraryPath pkgs.pythonManylinuxPackages.manylinux1;
            };
        };

        # Nix Package for Your Application
        packages.default = pythonSet.mkVirtualEnv (thisProjectAsNixPkg.pname + "-env") workspace.deps.default;
        packages.${thisProjectAsNixPkg.pname} = self.packages.${system}.default;

        # App for `nix run`
        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/${thisProjectAsNixPkg.pname}";
        };
        apps.${thisProjectAsNixPkg.pname} = self.apps.${system}.default;
      }
    );
}
