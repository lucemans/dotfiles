_: {
  flake.nixosModules.ingestarrPapers = _: {
    services.ingestarr.settings.source = [
      {
        key = "arxiv-cl";
        name = "arXiv cs.CL";
        kind = "arxiv";
        arxiv = {
          category = "cs.CL";
          keywords = ["speculative decoding" "diffusion language model" "KV cache" "ethereum"];
        };
      }
    ];
  };
}
