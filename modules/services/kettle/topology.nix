{
  forge = {
    host = "v3x-mediabus";
    port = 3500;
    # The hub's proxy serves HTTPS only, so git over SSH goes to `host` over wg0.
    sshPort = 2222;
  };
}
