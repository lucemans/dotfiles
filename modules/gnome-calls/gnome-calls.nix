{
  # NixOS module: patches gnome-calls v49.1.1 to fix FORTIFY_SOURCE crash
  #
  # calls-network-watch.c derives rtattr pointers from &self->req->n (16-byte
  # struct nlmsghdr) instead of self->req (full ~1060-byte RequestData struct).
  # glibc's FORTIFY_SOURCE inet_pton() sees the write landing at offset 32 of
  # a 16-byte object → false-positive __chk_fail() → SIGABRT.
  #
  # Fixed upstream in v50.0 by changing &self->req->n → self->req in both
  # req_route_v4() and req_route_v6(). Backported here as a 2-line patch.
  # Remove this when nixpkgs updates to calls >= 50.0.
  flake.nixosModules.gnome-calls = {...}: {
    nixpkgs.overlays = [
      (final: prev: {
        calls = prev.calls.overrideAttrs (old: {
          patches = (old.patches or []) ++ [./calls-fortify-fix.patch];
        });
      })
    ];
  };
}
