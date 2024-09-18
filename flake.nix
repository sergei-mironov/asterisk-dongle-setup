{
  description = "Asterisk-dongle setup";

  nixConfig = {
    bash-prompt = "\[ adongle \\w \]$ ";
  };

  inputs = {
    nixpkgs = {
      # Author's favorite nixpkgs
      url = "github:grwlf/nixpkgs/local17";
    };

    secrets = {
      url = "~/proj/asterisk-dongle-setup/secrets.nix";
      flake = false;
    };

  };

  outputs = { self, nixpkgs, secrets }:
    let
      defaults = system : (import ./default.nix) {
        pkgs = import nixpkgs { inherit system; };
        revision = if self ? rev then self.rev else null;
        secrets = import secrets.outPath;
      };
      defaults-x86_64 = defaults "x86_64-linux";
      defaults-aarch64 = defaults "aarch64-linux";
    in {
      packages = {
        x86_64-linux = defaults-x86_64;
        aarch64-linux = defaults-aarch64;
      };
      devShells = {
        x86_64-linux = { default = defaults-x86_64.shell; };
        aarch64-linux = { default = defaults-aarch64.shell; };
      };
    };

}
