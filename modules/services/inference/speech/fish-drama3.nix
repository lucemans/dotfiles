{inputs, ...}: {
  flake.nixosModules.fishDrama3Speech = {pkgs, lib, ...}: let
    source = inputs.audiocpp-src;
    audio = (pkgs.callPackage (source + "/.devops/nix/package.nix") {
      version = "eeeca9e";
      python-scripts = pkgs.callPackage (source + "/.devops/nix/python-scripts.nix") {};
      cudaSupport = true;
      nativeModelManagerSupport = false;
      models = ["fish_drama3"];
    }).overrideAttrs (old: {
      cmakeFlags = old.cmakeFlags ++ [
        "-DCMAKE_CUDA_ARCHITECTURES=86"
        "-DENGINE_ENABLE_NATIVE_CPU=OFF"
        "-DAUDIOCPP_DEPLOYMENT_BUILD=ON"
      ];
    });
    filename = "drama-3-backbone-8bit-experts-Q2_K.gguf";
    revision = "060acc8e5d9e5d16baf647c775dfe1a1438f5f35";
    checksum = "5cb86588eff6404f4482830cfd3d69713f27115c02530a29f772535262fb7826";
    state = "/var/lib/fish-drama3";
    serverConfig = (pkgs.formats.json {}).generate "fish-drama3.json" {
      host = "127.0.0.1";
      port = 8085;
      backend = "cuda";
      device = 0;
      threads = 8;
      lazy_load = true;
      max_loaded_models = 1;
      idle_unload_ms = 300000;
      log_request_body = false;
      ui = false;
      models = [{
        id = "fish-drama3";
        family = "fish_drama3";
        path = "${state}/${filename}";
        task = "tts";
        mode = "offline";
        session_options = {
          "fish_drama3.cpu_expert_layers" = 8;
          "fish_drama3.context_length" = 2048;
        };
        default_request_options.max_tokens = 500;
      }];
    };
  in {
    # Start explicitly after checking VRAM; llama-swap cannot coordinate this
    # separate process. No wantedBy: rebuilding must not load another GPU model.
    systemd.services.fish-drama3 = {
      description = "Fish Audio Drama 3 speech API (audio.cpp)";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      path = [pkgs.curl pkgs.coreutils];
      preStart = ''
        cd ${state}
        if ! test -f ${filename}; then
          curl --fail --location --retry 5 --continue-at - \
            https://huggingface.co/Jmica/Drama-3-GGUF/resolve/${revision}/${filename} \
            --output ${filename}.partial
          echo '${checksum}  ${filename}.partial' | sha256sum --check
          mv ${filename}.partial ${filename}
        fi
        echo '${checksum}  ${filename}' | sha256sum --check
      '';
      serviceConfig = {
        ExecStart = "${audio}/bin/audiocpp_server --config ${serverConfig} --no-ui";
        DynamicUser = true;
        SupplementaryGroups = ["video" "render"];
        StateDirectory = "fish-drama3";
        WorkingDirectory = state;
        TimeoutStartSec = "2h";
        Restart = "on-failure";
        RestartSec = "30s";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  };
}
