{config, ...}: let
  public_ip = "77.162.232.110";
  zone = "v3x.host";
in {
  sops.secrets = {
    asterisk_p1_password = {
      owner = "asterisk";
      group = "asterisk";
    };
    asterisk_p2_password = {
      owner = "asterisk";
      group = "asterisk";
    };
  };

  sops.templates.asterisk-auth = {
    owner = "asterisk";
    group = "asterisk";
    mode = "0440";
    content = ''
      [1001-auth]
      type = auth
      auth_type = userpass
      username = 1001
      password = ${config.sops.placeholder.asterisk_p1_password}
      [1002-auth]
      type = auth
      auth_type = userpass
      username = 1002
      password = ${config.sops.placeholder.asterisk_p2_password}
    '';
  };

  services.asterisk.confFiles."pjsip.conf" = ''
    [transport-tls]
    type=transport
    protocol=tls
    bind=0.0.0.0:5061
    external_signaling_address=${public_ip}
    external_media_address=${public_ip}
    local_net=100.127.0.0/16
    local_net=100.90.0.0/16
    local_net=100.0.0.0/16
    cert_file=/var/lib/acme/${zone}/fullchain.pem
    priv_key_file=/var/lib/acme/${zone}/key.pem
    ca_list_file=/etc/ssl/certs/ca-certificates.crt
    method=tlsv1_2
    verify_server=no

    [transport-udp]
    type=transport
    protocol=udp
    bind=0.0.0.0:5060 ; ${config.v3x.address}:5060

    #include "${config.sops.templates.asterisk-pjsip.path}"

    [1001]
    type=aor
    max_contacts=3
    remove_existing=yes

    [1001]
    type=endpoint
    transport=transport-udp
    context=from-internal
    auth=1001-auth
    aors=1001
    disallow=all
    allow=ulaw,alaw
    direct_media=no

    ; overwrite networking shenanigans
    rtp_symmetric=yes
    force_rport=yes
    rewrite_contact=yes
    rtp_timeout=60
    rtp_timeout_hold=300

    ; media_encryption=dtls
    ; dtls_auto_generate_cert=yes

    [1002]
    type=aor
    max_contacts=1

    [1002]
    type=endpoint
    transport=transport-udp
    context=from-internal
    auth=1002-auth
    aors=1002
    disallow=all
    allow=ulaw,alaw
    direct_media=no
    rtp_symmetric=yes
    force_rport=yes
    rewrite_contact=yes
    rtp_timeout=60
    rtp_timeout_hold=300

    #include "${config.sops.templates.asterisk-auth.path}"
  '';
}
