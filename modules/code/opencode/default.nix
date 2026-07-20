{inputs, ...}: {
  flake.nixosModules.opencode = {
    self,
    pkgs,
    ...
  }: let
    rules = import ../_rules;
    opencodeConfig =
      (builtins.fromJSON (builtins.readFile ./opencode.jsonc))
      // {
        mcp = self.mcp.opencode;
      };
    opencode = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.opencode;
      runtimeInputs = with pkgs; [
        lua-language-server
        marksman
        mdx-language-server
        taplo
        typescript-language-server
        vscode-langservers-extracted
        yaml-language-server
      ];
    };
    opencode2Package = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
      pname = "opencode2";
      version = "0.0.0-next-15885";
      src = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@opencode-ai/cli-linux-x64/-/cli-linux-x64-${finalAttrs.version}.tgz";
        hash = "sha512-H73PKr4AeNkSPrRFcjAiOaaibz8L1F4sqwPKNvtX+TYDUtEUJlHtFfc0OOhPVAvM/TsiL405Ot3lh6UagwLXUg==";
      };
      unpackPhase = ''
        tar -xzf $src
      '';
      installPhase = ''
        install -Dm755 package/bin/opencode2 $out/libexec/opencode2
      '';
    });
    opencode2 = pkgs.writeShellApplication {
      name = "opencode2";
      runtimeInputs = with pkgs; [
        steam-run
        lua-language-server
        marksman
        mdx-language-server
        taplo
        typescript-language-server
        vscode-langservers-extracted
        yaml-language-server
      ];
      text = ''
        exec steam-run ${opencode2Package}/libexec/opencode2 "$@"
      '';
    };
    opencode2Update = pkgs.writeShellApplication {
      name = "opencode2-update";
      runtimeInputs = with pkgs; [curl jq perl];
      text = ''
        set -o nounset

        metadata="$(curl --fail --silent --show-error https://registry.npmjs.org/@opencode-ai/cli-linux-x64/next)"
        version="$(jq --raw-output '.version' <<<"$metadata")"
        hash="$(jq --raw-output '.dist.integrity' <<<"$metadata")"
        module=/etc/nixos/modules/code/opencode/default.nix
        current="$(perl -ne 'print $1 if /version = "([^"]+)";/' "$module")"

        if [ "$current" = "$version" ]; then
          printf 'OpenCode 2 is already pinned at %s\n' "$version"
          exit 0
        fi

        if [ "''${1:-}" = "--check" ]; then
          printf 'OpenCode 2 update available: %s -> %s\n' "$current" "$version"
          exit 0
        fi

        VERSION="$version" HASH="$hash" perl -0pi -e '
          s/(version = ")[^"]+(";\n      src = pkgs\.fetchurl)/$1$ENV{VERSION}$2/;
          s/(hash = ")[^"]+(";\n      };\n      unpackPhase)/$1$ENV{HASH}$2/;
        ' "$module"

        printf 'Updated OpenCode 2 to %s. Rebuild the NixOS configuration to install it.\n' "$version"
      '';
    };
  in {
    environment.systemPackages = [opencode opencode2 opencode2Update];

    environment.sessionVariables = {
      OPENCODE_DISABLE_CHANNEL_DB = "1";
    };

    home-manager.users.luc.home.sessionVariables = {
      OPENCODE_DISABLE_CHANNEL_DB = "1";
    };

    home-manager.users.luc.home.file =
      (rules.mkSkillFiles ".config/opencode/skills")
      // {
        ".config/opencode/opencode.jsonc" = {
          text = builtins.toJSON opencodeConfig;
          force = true;
        };

        ".config/opencode/AGENTS.md" = {
          source = rules.policy;
          force = true;
        };

        ".config/opencode/agents/visual-qa.md" = {
          source = ./agents/visual-qa.md;
          force = true;
        };
      };
  };
}
