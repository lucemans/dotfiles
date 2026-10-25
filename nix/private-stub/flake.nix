{
  description = "Stand-in for dotfiles-private, for builds without access to it";

  outputs = _: {
    nixosModules.pirateship = {};
  };
}
