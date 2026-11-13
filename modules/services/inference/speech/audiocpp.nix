{
  pkgs,
  source,
}:
(pkgs.callPackage (source + "/.devops/nix/package.nix") {
  version = "eeeca9e";
  python-scripts = pkgs.emptyDirectory;
  cudaSupport = true;
  nativeModelManagerSupport = false;
  models = ["fish_drama3" "qwen3_tts"];
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
})
