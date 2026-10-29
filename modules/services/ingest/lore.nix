_: {
  flake.nixosModules.ingestarrLore = _: {
    services.ingestarr.settings.source = [
      {
        key = "lore-linux-btrfs";
        name = "linux-btrfs";
        kind = "lore";
        interval = "1h";
        lore = {
          list = "linux-btrfs";
          only_new_threads = true;
        };
      }
      {
        key = "lore-amd-gfx";
        name = "amd-gfx";
        kind = "lore";
        interval = "1h";
        lore = {
          list = "amd-gfx";
          only_new_threads = true;
        };
      }
    ];
  };
}
