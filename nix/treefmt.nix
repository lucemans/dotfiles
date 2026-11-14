{
  perSystem = _: {
    treefmt = {
      programs.deadnix = {
        enable = true;
        priority = 1;
      };

      programs.statix = {
        enable = true;
        priority = 2;
        disabled-lints = ["repeated_keys"];
      };

      programs.alejandra = {
        enable = true;
        priority = 3;
      };
    };
  };
}
