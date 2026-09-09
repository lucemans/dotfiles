{
  perSystem = _: {
    treefmt = {
      programs.deadnix = {
        enable = true;
        priority = 1;
      };

      # `repeated_keys` reads a flat `services.foo = ...; services.bar = ...;`
      # as a mistake. That is how a NixOS module is written, so the lint fires
      # on almost every file here and says nothing.
      programs.statix = {
        enable = true;
        priority = 2;
        disabled-lints = ["repeated_keys"];
      };

      # Last, so neither fixer above leaves its own spacing behind.
      programs.alejandra = {
        enable = true;
        priority = 3;
      };
    };
  };
}
