# Pinned sources for every GGUF that llama-swap serves on mediabus.
# Each entry is a Hugging Face repo at an exact commit, with the sha256 of the file.
# The fetch service in mediabus-inference.nix downloads and verifies them.
{
  "qwen3.6-35b-a3b" = {
    repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
    rev = "a483e9e6cbd595906af30beda3187c2663a1118c";
    file = "Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
    sha256 = "707a55a8a4397ecde44de0c499d3e68c1ad1d240d1da65826b4949d1043f4450";
  };
  "qwen2.5-coder-1.5b" = {
    repo = "ggml-org/Qwen2.5-Coder-1.5B-Q8_0-GGUF";
    rev = "8be1b8a895a84beea772817caaa71eba6b6e0d07";
    file = "qwen2.5-coder-1.5b-q8_0.gguf";
    sha256 = "29871c94d15727a6e243f79a37113d4ae625a6215b5e800bf41a23af2da32832";
  };
  "qwen3-8b" = {
    repo = "ggml-org/Qwen3-8B-GGUF";
    rev = "bbd9eb5efae3fd6d45dd620650916346d7cecc67";
    file = "Qwen3-8B-Q8_0.gguf";
    sha256 = "2f98cff159bcdf01431829406d43363ccacb76ed6b76d18bd9d6ab20976792c0";
  };
  "qwen3-8b-dflash" = {
    repo = "ggml-org/Qwen3-8B-GGUF";
    rev = "bbd9eb5efae3fd6d45dd620650916346d7cecc67";
    file = "dflash-Qwen3-8B-Q8_0.gguf";
    sha256 = "89a3d462b8e945c602599a91ab2329aa387f677d88383d0e23253b9f0082e502";
  };
  "qwen2.5-coder-7b" = {
    repo = "ggml-org/Qwen2.5-Coder-7B-Q8_0-GGUF";
    rev = "bca77e0a8c88fc224882bcc404170c3ef17efacc";
    file = "qwen2.5-coder-7b-q8_0.gguf";
    sha256 = "0ef48dc94a3c551a6736ac2601de38413dc9aa9318534b16e8baee08290a4aaf";
  };
  "sweep-next-edit-1.5b" = {
    repo = "sweepai/sweep-next-edit-1.5B";
    rev = "409016591c6c1a94f545f22328a85a3516118f34";
    file = "sweep-next-edit-1.5b.q8_0.v2.gguf";
    sha256 = "1321ea5e5d7529e60f9770c6a0b3a965f89542d16cf4ae51bab267f6a88150da";
  };
  "sweep-next-edit-v2-7b" = {
    repo = "henrik3/sweep-next-edit-v2-7B-GGUF";
    rev = "f88a6bc2316f6b7f9581668ae51909478d13e685";
    file = "q5_k_m.gguf";
    sha256 = "e232581569e4584de3afdfeb06d7fba2a1298d0d3a1e4c2b513927d7a495dc46";
  };
  "gpt-oss-20b" = {
    repo = "unsloth/gpt-oss-20b-GGUF";
    rev = "d449b42d93e1c2c7bda5312f5c25c8fb91dfa9b4";
    file = "gpt-oss-20b-F16.gguf";
    sha256 = "4e4f9cd88d6456e4f389e7262eca4a8d565211e2b22ece9ca7a8556168ff3c66";
  };
  "qwen3-coder-30b-a3b" = {
    repo = "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF";
    rev = "b17cb02dd882d5b6ab62fc777ad2995f19668350";
    file = "Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf";
    sha256 = "fadc3e5f8d42bf7e894a785b05082e47daee4df26680389817e2093056f088ad";
  };
  "muse-glimmer-30b" = {
    repo = "meta-models/Muse-Glimmer-30B-GGUF";
    rev = "a0532f7263ee67f1e0a5f5c5fdcd50dd62fc9aa4";
    file = "muse-glimmer-30B-kquant-17gb.gguf";
    sha256 = "7e9b74b7c8875e9e265695df9613bf6290f2392e479ce740495a129019c488d8";
  };
  "muse-glimmer-30b-draft" = {
    repo = "meta-models/Muse-Glimmer-30B-GGUF";
    rev = "a0532f7263ee67f1e0a5f5c5fdcd50dd62fc9aa4";
    file = "dflash-kquant.gguf";
    sha256 = "27d9a805fa29b943cfb6ad4843367cd4eaaaf06bd452d8cc3e00a2cd18a677bc";
  };
  "qwen3.8-27b" = {
    repo = "unsloth/Qwen3.8-27B-GGUF";
    rev = "f1bfb127c64f7072bdd2cad55f258b9c8b2910fe";
    file = "Qwen3.8-27B-UD-Q5_K_XL.gguf";
    sha256 = "176a6a3f034e9cdc447c10cd00329fc9b31002e6589b9295f2ad4f1eefe0f6ab";
  };
  "nex-n2.5-mini" = {
    repo = "bartowski/nex-agi_Nex-N2.5-mini-GGUF";
    rev = "0048da1ad2ad33fdcf8b24bc12185cdebfe459d6";
    file = "nex-agi_Nex-N2.5-mini-Q4_0.gguf";
    sha256 = "0fe15b40ff686e4389eeb9b193ca2dc4380e40039594d573a1335f738d72155b";
  };
  "minicpm5-2b" = {
    repo = "bartowski/MiniCPM5-2B-GGUF";
    rev = "31fee0334c4ed9f1e079afe586ba30cb83e0f883";
    file = "MiniCPM5-2B-bf16.gguf";
    sha256 = "92b5df1d7e1444fa0baa925521130e367cf1267edd66904cbf0afe281765382c";
  };
  "nex-n2.5-mini-uncensored" = {
    repo = "orcarouter/Nex-N2.5-mini-Uncensored-GGUF";
    rev = "59f36a2cd1e5c64139e271b5b406a014b68109ef";
    file = "Nex-N2.5-mini-Uncensored-Q3_K_M.gguf";
    sha256 = "09b29439812458a2a4f0d0d61998ddd5ecba8eb49e7604793f420ee9b2cee3ec";
    gated = true;
  };
  "qwen3-embedding-0.6b" = {
    repo = "Qwen/Qwen3-Embedding-0.6B-GGUF";
    rev = "370f27d7550e0def9b39c1f16d3fbaa13aa67728";
    file = "Qwen3-Embedding-0.6B-f16.gguf";
    sha256 = "421a27e58d165478cc7acb984a688c2aa41404968b0203e7cd743ece44c54340";
  };
  "zeta-2.1" = {
    repo = "mradermacher/zeta-2.1-i1-GGUF";
    rev = "92c5ffc501a76d9c92bd04c0022cebfffa461dc8";
    file = "zeta-2.1.i1-Q4_K_M.gguf";
    sha256 = "216ddb5722a49f9ff49b21a050c4db3c801ef6f34e4bd1702d5db43e3325b076";
  };
  "qwen3.8-flash-next-1" = {
    repo = "unsloth/Qwen3.8-Flash-Next-GGUF";
    rev = "38bb39ee97821de2c9009abb7e93950eec396e66";
    file = "UD-IQ4_XS/Qwen3.8-Flash-Next-UD-IQ4_XS-00001-of-00003.gguf";
    sha256 = "5ce89370720f8bf90890f439361282104c1aa1482d4013bb9a50923e758e71a4";
  };
  "qwen3.8-flash-next-2" = {
    repo = "unsloth/Qwen3.8-Flash-Next-GGUF";
    rev = "38bb39ee97821de2c9009abb7e93950eec396e66";
    file = "UD-IQ4_XS/Qwen3.8-Flash-Next-UD-IQ4_XS-00002-of-00003.gguf";
    sha256 = "577a38a2392b40ca2193cea502e1d92f60b8cd370675d308e0ec21885d9daaa7";
  };
  "qwen3.8-flash-next-3" = {
    repo = "unsloth/Qwen3.8-Flash-Next-GGUF";
    rev = "38bb39ee97821de2c9009abb7e93950eec396e66";
    file = "UD-IQ4_XS/Qwen3.8-Flash-Next-UD-IQ4_XS-00003-of-00003.gguf";
    sha256 = "d4634e6d84f0ebb0940be15c90d3790bf6464e3dea3a1cddc567dc0e83ad8833";
  };
  "hemmingway-1" = {
    repo = "bartowski/Altworld_Hemmingway-1-GGUF";
    rev = "259605e26a47f2dcc8731ae1aa7305f8047d2c6d";
    file = "Altworld_Hemmingway-1-Q4_K_M.gguf";
    sha256 = "c029ba6cc24bc022a65d00e4d81796ff0bd678e371a36c9a7d1119a0acc7085e";
  };
}
