{inputs, ...}: let
  voxtype = inputs.voxtype;

  voxtypeModule = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.programs.voxtype;
    tomlFormat = pkgs.formats.toml {};

    modelDefs = import "${voxtype}/nix/models.nix";
    defaultSettings = fromTOML (builtins.readFile "${voxtype}/config/default.toml");

    onnxEngines = ["parakeet" "moonshine" "sensevoice" "paraformer" "dolphin" "omnilingual"];
    isOnnxEngine = builtins.elem cfg.engine onnxEngines;

    fetchedModel = lib.optionalAttrs (cfg.model.name != null) (
      let
        modelDef = modelDefs.${cfg.model.name};
      in
        pkgs.fetchurl {inherit (modelDef) url hash;}
    );

    resolvedModelPath =
      if cfg.model.path != null
      then cfg.model.path
      else if cfg.model.name != null
      then fetchedModel
      else null;

    settings =
      lib.recursiveUpdate
      (lib.filterAttrs (_: v: v != null) {
        engine = cfg.engine;
        ${cfg.engine} = lib.optionalAttrs (resolvedModelPath != null) {
          model = toString resolvedModelPath;
        };
      })
      cfg.settings;

    configFile =
      tomlFormat.generate "voxtype-config.toml"
      (lib.recursiveUpdate defaultSettings settings);
  in {
    options.programs.voxtype = {
      enable = lib.mkEnableOption "voxtype push-to-talk voice-to-text";

      engine = lib.mkOption {
        type = lib.types.enum (["whisper"] ++ onnxEngines);
        default = "whisper";
        description = "Speech recognition engine. ONNX engines need model.path and an onnx* package.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = voxtype.packages.${pkgs.system}.default;
        defaultText = lib.literalExpression "inputs.voxtype.packages.\${pkgs.system}.default";
        description = ''
          Wrapped voxtype package from the flake:
            default / vulkan / rocm            — Whisper
            onnx / onnx-cuda / onnx-rocm       — ONNX engines
        '';
      };

      model = {
        name = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum (builtins.attrNames modelDefs));
          default = null;
          description = "Whisper model to fetch from HuggingFace (whisper engine only).";
        };
        path = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to a .bin (Whisper) or model directory (ONNX). Overrides model.name.";
        };
      };

      settings = lib.mkOption {
        type = tomlFormat.type;
        default = {};
        description = "Settings merged over upstream default.toml and written to /etc/voxtype/config.toml.";
      };

      service.enable = lib.mkEnableOption "the voxtype systemd user service";
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !(cfg.model.name != null && cfg.model.path != null);
          message = "programs.voxtype: cannot set both model.name and model.path";
        }
        {
          assertion = !(isOnnxEngine && cfg.model.name != null);
          message = "programs.voxtype: model.name is Whisper-only; use model.path for ${cfg.engine}";
        }
      ];

      environment.systemPackages = [cfg.package];
      environment.etc."voxtype/config.toml".source = configFile;

      systemd.user.services.voxtype = lib.mkIf cfg.service.enable {
        description = "VoxType push-to-talk voice-to-text daemon";
        documentation = ["https://voxtype.io"];
        partOf = ["graphical-session.target"];
        after = ["graphical-session.target" "pipewire.service" "pipewire-pulse.service"];
        wantedBy = ["graphical-session.target"];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${cfg.package}/bin/voxtype daemon";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    };
  };
in {
  flake.nixosModules.voxtype = {
    lib,
    pkgs,
    ...
  }: {
    imports = [voxtypeModule];

    users.users.luc.extraGroups = ["input" "ydotool"];

    programs.ydotool.enable = true;

    programs.voxtype = {
      enable = true;
      package = voxtype.packages.${pkgs.system}.onnx-cuda;
      engine = "parakeet";
      model.path = "/home/luc/.local/share/voxtype/models/parakeet-unified-en-0.6b";
      service.enable = true;
      settings = {
        parakeet = {
          streaming = true;
          streaming_chunk_secs = 0.56;
          streaming_left_context_secs = 5.6;
          streaming_right_context_secs = 0.56;
        };
        hotkey.enabled = false;
        hotkey.mode = "toggle";
      };
    };

    home-manager.users.luc = {
      programs.plasma.hotkeys.commands = {
        "launch-voxtype" = {
          name = "Launch Voxtype";
          key = "Alt+Shift+T";
          command = "voxtype record toggle";
        };
      };
    };

    systemd.user.services.voxtype = {
      # Every output backend probes itself with `which`, which is absent from
      # the minimal PATH NixOS gives user services.
      path = [voxtype.packages.${pkgs.system}.osd-gtk4 pkgs.which];
      environment = {
        # The flake wrapper only puts onnxruntime on LD_LIBRARY_PATH; the CUDA
        # probe dlopens libcudart.so by bare name and falls back to CPU without it.
        LD_LIBRARY_PATH =
          lib.makeLibraryPath [pkgs.cudaPackages.cuda_cudart pkgs.cudaPackages.cudnn];
        # programs.ydotool exports this only to login shells, not to user services.
        YDOTOOL_SOCKET = "/run/ydotoold/socket";
      };
    };
  };
}
