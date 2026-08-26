# networking

## provisioning

```
sudo install -d -m 0755 /var/lib/wireguard
nix shell nixpkgs#wireguard-tools -c sudo sh -c 'umask 077; wg genkey > /var/lib/wireguard/wg0.key'
sudo cat /var/lib/wireguard/wg0.key | nix shell nixpkgs#wireguard-tools -c wg pubkey
```

## openwrt

Provision wireguard creds:

```
for n in 1 2; do
  key=$(wg genkey)
  echo "=== box $n, address 100.127.10.$n ==="
  echo "public key: $(echo "$key" | wg pubkey)"
  echo
  cat <<EOF
[Interface]
PrivateKey = $key
Address = 100.127.10.$n/32

[Peer]
PublicKey = 8FDbnPsRkbhl/Req/KfND0pT3+6aoNjohiOiAUlXFGc=
Endpoint = wg.v3x.host:51820
AllowedIPs = 100.127.0.0/16
PersistentKeepalive = 25
EOF
  echo
done
```

Upload to `Network > Interfaces`.
Assign interface to `wan` in `Network > Firewall`.
Ensure to edit peer info and tick `route allowed ips`.
And firewall settings to change zone to `wan`.

Add management rule `Network > Filewall > Traffic Rules`:
```
source zone wan
source address 100.127.0.0/24
destination address `input`
destination port 22
```

Add to `DNS > Forwarding`: `/v3x.host/100.127.0.53`

Add `v3x.host` to `Domain whitelist` on `Fitler`.
