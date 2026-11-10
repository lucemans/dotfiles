{
  config,
  lib,
  ...
}: let
  signaling_nets = [
    "54.172.60.0/23"
    "54.244.51.0/24"
    "54.171.127.192/26"
    "35.156.191.128/25"
    "54.65.63.192/26"
    "54.169.127.128/26"
    "54.252.254.64/26"
    "177.71.206.192/26"
  ];
in {
  _module.args = {inherit signaling_nets;};

  sops.secrets.sip_trunk_host = {
    owner = "asterisk";
    group = "asterisk";
  };

  sops.templates.asterisk-pjsip = {
    owner = "asterisk";
    group = "asterisk";
    mode = "0400";
    content = ''
      [trunk-aor]
      type=aor
      contact=sip:${config.sops.placeholder.sip_trunk_host}:5061
      qualify_frequency=60
      qualify_timeout=5

      [trunk]
      type=endpoint
      transport=transport-tls
      context=from-trunk
      aors=trunk-aor
      identify_by=ip
      from_domain=${config.sops.placeholder.sip_trunk_host}
      disallow=all
      allow=ulaw
      allow=alaw
      media_encryption=sdes
      direct_media=no
      rtp_symmetric=yes
      force_rport=yes
      rewrite_contact=yes
      trust_id_outbound=yes
      rtp_timeout=60
      rtp_timeout_hold=300

      [trunk-identify]
      type=identify
      endpoint=trunk
      ${lib.concatMapStringsSep "\n" (net: "match=${net}") signaling_nets}
    '';
  };
}
