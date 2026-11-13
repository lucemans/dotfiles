{
  pkgs,
  source,
  dir,
}: let
  audio =
    (pkgs.callPackage (source + "/.devops/nix/package.nix") {
      version = "eeeca9e";
      python-scripts = pkgs.emptyDirectory;
      cudaSupport = true;
      nativeModelManagerSupport = false;
      models = ["fish_drama3"];
    }).overrideAttrs (old: {
      cmakeFlags =
        pkgs.lib.remove "-DCMAKE_BUILD_TYPE=RelWithDebInfo" old.cmakeFlags
        ++ [
          "-DCMAKE_CUDA_ARCHITECTURES=86"
          "-DENGINE_ENABLE_NATIVE_CPU=OFF"
          "-DAUDIOCPP_DEPLOYMENT_BUILD=ON"
        ];
      ninjaFlags = ["audiocpp_server"];
      installPhase = ''
        runHook preInstall
        install -Dm755 bin/audiocpp_server $out/bin/audiocpp_server
        runHook postInstall
      '';
    });
  filename = "drama-3-backbone-8bit-experts-Q2_K.gguf";
  file = {
    repo = "Jmica/Drama-3-GGUF";
    rev = "060acc8e5d9e5d16baf647c775dfe1a1438f5f35";
    file = filename;
    sha256 = "5cb86588eff6404f4482830cfd3d69713f27115c02530a29f772535262fb7826";
    gated = false;
    dest = "${dir}/Jmica--Drama-3-GGUF/${filename}";
  };
  serverConfig = (pkgs.formats.json {}).generate "fish-drama3.json" {
    host = "127.0.0.1";
    backend = "cuda";
    device = 0;
    threads = 8;
    lazy_load = false;
    ui = false;
    models = [
      {
        id = "fish-drama3";
        family = "fish_drama3";
        path = file.dest;
        task = "tts";
        mode = "offline";
        session_options = {
          "fish_drama3.cpu_expert_layers" = 8;
          "fish_drama3.context_length" = 2048;
        };
        default_request_options.max_tokens = 500;
      }
    ];
  };
in {
  inherit file;
  swap = {
    cmd = "${audio}/bin/audiocpp_server --config ${serverConfig} --no-ui --port \${PORT}";
    checkEndpoint = "/health";
    ttl = 300;
    concurrencyLimit = 1;
  };
}
