{
  inputs,
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    ...
  }: let
    fishConf = pkgs.writeText "fish-config" ''
      function fish_prompt
        string join "" -- (set_color red) "[" (set_color yellow) $USER (set_color green) "@" (set_color blue) $hostname (set_color magenta) " " (prompt_pwd) (set_color red) ']' (set_color normal) "\$ "
      end

      set fish_greeting
      fish_vi_key_bindings

      if type -q zoxide
        zoxide init fish | source
      end
    '';
  in {
    packages.fish = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.fish;
      runtimeInputs = [pkgs.zoxide];
      flags = {
        "-C" = "source ${fishConf}";
      };
    };
  };
}
