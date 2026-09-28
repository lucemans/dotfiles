_: {
  # Qwen3-TTS through vLLM-Omni, which clones a voice from a short clip and its
  # transcript. vLLM-Omni and its CUDA stack are not in nixpkgs, so the
  # upstream image runs as a container.
  flake.nixosModules.qwen3Speech = {pkgs, ...}: let
    port = 8084;
    stateDir = "/var/lib/qwen3-speech";
    name = "qwen3-tts";

    model = "Qwen/Qwen3-TTS-12Hz-1.7B-Base";
    revision = "fd4b254389122332181a7c3db7f27e918eec64e3";

    references = import ../../desktop/tts-speak/references.nix pkgs;
    voices = ["glados" "cave" "ada" "elmo"];

    # The upstream qwen3_tts.yaml from v0.30.0, sized for one listener on a
    # 12 GB card that llama.cpp shares: 64 parallel sequences become 4, and
    # the two stages hold about 6.4 GB between them instead of 7.2 GB. With
    # the weights loaded that leaves the talker too little cache for its
    # upstream 4096 frames, and 2048 frames is still over two minutes of
    # speech for a request that carries one clause.
    frames = 2048;
    # The code-to-wave stage sees all 16 codebooks of every frame.
    codes = 16 * frames;

    deploy = (pkgs.formats.yaml {}).generate "qwen3-tts-deploy.yaml" {
      model_runner = "v2";
      async_chunk = true;

      connectors.connector_of_shared_memory = {
        name = "SharedMemoryConnector";
        extra = {
          codec_streaming = true;
          connector_get_sleep_s = 0.01;
          connector_get_max_wait_first_chunk = 3000;
          connector_get_max_wait = 300;
          codec_chunk_frames = 25;
          codec_left_context_frames = 72;
          initial_codec_chunk_frames = 1;
          decode_batch_max_size = 4;
        };
      };

      stages = [
        {
          stage_id = 0;
          max_num_seqs = 4;
          gpu_memory_utilization = 0.38;
          trust_remote_code = true;
          enable_prefix_caching = false;
          async_scheduling = true;
          max_num_batched_tokens = 512;
          max_model_len = frames;
          devices = "0";
          output_connectors.to_stage_1 = "connector_of_shared_memory";
          default_sampling_params = {
            temperature = 0.9;
            top_k = 50;
            max_tokens = frames;
            min_tokens = 2;
            repetition_penalty = 1.05;
          };
          silence_ban_frames = 0;
          subtalker_sampling_params = {
            do_sample = true;
            temperature = 0.9;
            top_k = 50;
            top_p = 1.0;
          };
        }
        {
          stage_id = 1;
          dtype = "bfloat16";
          max_num_seqs = 4;
          gpu_memory_utilization = 0.15;
          enforce_eager = false;
          trust_remote_code = true;
          enable_prefix_caching = false;
          async_scheduling = true;
          max_num_batched_tokens = codes;
          max_model_len = codes;
          devices = "0";
          input_connectors.from_stage_0 = "connector_of_shared_memory";
          default_sampling_params = {
            temperature = 0.0;
            top_p = 1.0;
            top_k = -1;
            max_tokens = codes;
            repetition_penalty = 1.0;
          };
        }
      ];
    };
  in {
    hardware.nvidia-container-toolkit.enable = true;

    systemd.tmpfiles.rules = [
      "d ${stateDir}/huggingface 0755 root root -"
      "d ${stateDir}/voices 0755 root root -"
    ];

    virtualisation.oci-containers.containers.qwen3-speech = {
      image = "vllm/vllm-omni:v0.30.0@sha256:fc77cfaac7b1b43c30cbf32eaea214864434c6e0f303e6e9eb9f64104241a994";
      entrypoint = "vllm";
      cmd = [
        "serve"
        model
        "--revision"
        revision
        "--served-model-name"
        name
        "--omni"
        "--host"
        "0.0.0.0"
        "--port"
        (toString port)
        "--deploy-config"
        "/etc/qwen3-tts.yaml"
        "--trust-remote-code"
      ];
      ports = ["127.0.0.1:${toString port}:${toString port}"];
      volumes = [
        "${stateDir}/huggingface:/root/.cache/huggingface"
        "${stateDir}/voices:/voices"
        "${deploy}:/etc/qwen3-tts.yaml:ro"
      ];
      environment.SPEAKER_SAMPLES_DIR = "/voices";
      # The two stages hand audio codes over through shared memory, which the
      # 64 MB /dev/shm of a default container cannot hold.
      extraOptions = ["--device=nvidia.com/gpu=all" "--ipc=host"];
    };

    # The server keeps uploaded voices across restarts, but uploading on every
    # start keeps them in step with the reference clips in the store.
    systemd.services.qwen3-speech-voices = {
      description = "Upload the cloned voices to the Qwen3 speech server";
      after = ["docker-qwen3-speech.service"];
      bindsTo = ["docker-qwen3-speech.service"];
      wantedBy = ["docker-qwen3-speech.service"];
      path = [pkgs.curl];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # The first start downloads the image and the model before it listens.
        TimeoutStartSec = "1h";
      };
      script = ''
        until curl --silent --fail http://127.0.0.1:${toString port}/v1/audio/voices > /dev/null; do
          sleep 5
        done
        ${pkgs.lib.concatMapStrings (voice: ''
            curl --silent --show-error --fail \
              --form audio_sample=@${references}/${voice}.wav \
              --form name=${voice} \
              --form consent=luc \
              --form ref_text=\<${references}/${voice}.txt \
              http://127.0.0.1:${toString port}/v1/audio/voices
          '')
          voices}
      '';
    };
  };
}
