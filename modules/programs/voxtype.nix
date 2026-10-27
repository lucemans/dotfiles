{inputs, ...}: let
  inherit (inputs) voxtype;

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
        inherit (cfg) engine;
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
        default = voxtype.packages.${pkgs.stdenv.hostPlatform.system}.default;
        defaultText = lib.literalExpression "inputs.voxtype.packages.\${pkgs.stdenv.hostPlatform.system}.default";
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
        inherit (tomlFormat) type;
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
          ExecStart = "${cfg.package}/bin/voxtype --config /etc/voxtype/config.toml daemon";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    };
  };
in {
  flake.nixosModules.voxtype = {
    config,
    lib,
    pkgs,
    self,
    ...
  }: let
    cfg = config.programs.voxtype;
    nemotron = cfg.dictationModel == "nemotron";
    local = cfg.dictationServer == null;
    endpoint =
      if local
      then config.services.nemoSpeech.endpoint
      else cfg.dictationServer;
    packages = import ./voxtype/packages.nix {inherit pkgs voxtype;};
    vocabularyFile = import ./voxtype/vocabulary.nix {
      inherit lib pkgs;
      inherit (cfg.vocabulary) words corrections;
    };
  in {
    imports = [voxtypeModule self.nixosModules.nemoSpeech];

    options.programs.voxtype = {
      dictationModel = lib.mkOption {
        type = lib.types.enum ["nemotron" "parakeet-unified"];
        default = "nemotron";
        description = "Local dictation profile. Nemotron streams from a NeMo-Speech.cpp server with live preview and vocabulary; Parakeet runs in process on CUDA.";
      };

      dictationServer = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "http://100.127.0.11:8010";
        description = ''
          Base URL of the speech server. Null runs one on this machine through
          services.nemoSpeech; a URL uses a server running elsewhere, for
          example the same module on the GPU host.
        '';
      };

      vocabulary = {
        words = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["Nextcloud" "kubectl"];
          description = "Terms the recognizer is biased toward.";
        };
        corrections = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          example = {"next cloud" = "Nextcloud";};
          description = "Misheard text rewritten before it is typed. The replacement is also boosted.";
        };
      };
    };

    config = {
      users.users.luc.extraGroups = ["input" "ydotool"];

      programs.ydotool.enable = true;

      services.nemoSpeech.enable = lib.mkIf (nemotron && local) true;

      programs.voxtype = {
        enable = true;
        package =
          if nemotron
          then packages.daemon
          else voxtype.packages.${pkgs.stdenv.hostPlatform.system}.onnx-cuda;
        engine =
          if nemotron
          then "whisper"
          else "parakeet";
        model.path = lib.mkIf (!nemotron) "/home/luc/.local/share/voxtype/models/parakeet-unified-en-0.6b";
        service.enable = true;
        settings = {
          whisper = lib.mkIf nemotron {
            model = "nemotron-speech-streaming";
            mode = "remote";
            remote_endpoint = endpoint;
            remote_model = "nemotron-speech-streaming";
            remote_realtime = true;
            # The system file first, so a user entry overrides it.
            vocabulary_files = ["/etc/voxtype/vocabulary.txt" "~/.config/voxtype/vocabulary.txt"];
            language = "en";
            streaming = true;
            on_demand_loading = false;
          };
          osd = lib.mkIf nemotron {
            frontend = "gtk4";
            width_px = 520;
          };
          parakeet = lib.mkIf (!nemotron) {
            streaming = true;
            streaming_chunk_secs = 0.16;
            streaming_left_context_secs = 5.6;
            streaming_right_context_secs = 0.40;
          };
          hotkey.enabled = false;
          hotkey.mode = "toggle";
          # The default chain tries wtype, then dotool, before ydotool. KDE has
          # no virtual-keyboard protocol for wtype and nothing here runs dotoold,
          # so every streamed word would pay for two failed spawns first.
          output.driver_order = ["ydotool"];
        };
      };

      environment.etc."voxtype/vocabulary.txt".source = vocabularyFile;
      environment.systemPackages = [packages.vocab];

      home-manager.users.luc = {
        programs.plasma.hotkeys.commands = {
          "launch-voxtype" = {
            name = "Launch Voxtype";
            key = "Scroll Lock";
            command = "voxtype --config /etc/voxtype/config.toml record toggle";
          };
        };
      };

      systemd.user.services.voxtype = {
        # Every output backend probes itself with `which`, which is absent from
        # the minimal PATH NixOS gives user services.
        path = [
          (
            if nemotron
            then packages.osd
            else voxtype.packages.${pkgs.stdenv.hostPlatform.system}.osd-gtk4
          )
          pkgs.which
        ];
        environment = {
          # The flake wrapper only puts onnxruntime on LD_LIBRARY_PATH; the CUDA
          # probe dlopens libcudart.so by bare name and falls back to CPU without it.
          LD_LIBRARY_PATH = lib.mkIf (!nemotron) (
            lib.makeLibraryPath [pkgs.cudaPackages.cuda_cudart pkgs.cudaPackages.cudnn]
          );
          VOXTYPE_CONFIG = "/etc/voxtype/config.toml";
          VOXTYPE_PREVIEW_FILE = lib.mkIf nemotron "%t/voxtype/preview.txt";
          # programs.ydotool exports this only to login shells, not to user services.
          YDOTOOL_SOCKET = "/run/ydotoold/socket";
        };
        serviceConfig.UMask = "0077";
      };
    };
  };

  perSystem = {pkgs, ...}: let
    packages = import ./voxtype/packages.nix {inherit pkgs voxtype;};
  in {
    packages = {
      voxtype-dictation = packages.daemon;
      voxtype-preview = packages.osd;
      voxtype-vocab = packages.vocab;
    };
    checks.voxtype-vocab = packages.vocabTests;
  };
}
