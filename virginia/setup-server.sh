#!/usr/bin/env bash
# Run as root on the Virginia host, passing the Mac peer's public key.
set -euo pipefail
umask 077
peer=${1:?Pass the Mac public key}
port=${2:-51820}
[[ $peer =~ ^[A-Za-z0-9+/]{43}=$ && $port =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)) || exit 2
install -d -m 700 /etc/wireguard
cd /etc/wireguard
if [[ ! -e wg0.conf ]]; then
    outside=$(ip -4 route show default | awk 'NR==1 {print $5}')
    [[ $outside =~ ^[a-zA-Z0-9_.-]+$ ]]
    conf=$(mktemp .wg0.XXXXXXXX)
    trap 'rm -f "$conf"' EXIT
    {
        echo '[Interface]'
        printf 'PrivateKey = '; wg genkey
        echo 'Address = 10.9.0.1/24, fd00:9::1/64'
        echo "ListenPort = $port"
        for fw in iptables ip6tables; do
            subnet=10.9.0.0/24
            [[ $fw == ip6tables ]] && subnet=fd00:9::/64
            for action in PostUp PostDown; do
                op=-A
                [[ $action == PostDown ]] && op=-D
                echo "$action = $fw $op FORWARD -i %i -o $outside -j ACCEPT"
                echo "$action = $fw $op FORWARD -i $outside -o %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT"
                echo "$action = $fw -t nat $op POSTROUTING -o $outside -s $subnet -j MASQUERADE"
            done
        done
        echo '[Peer]'
        echo "PublicKey = $peer"
        echo 'AllowedIPs = 10.9.0.2/32, fd00:9::2/128'
    } > "$conf"
    ln "$conf" wg0.conf
fi
systemctl enable --now wg-quick@wg0
wg show wg0 peers | grep -Fxq "$peer" || { echo 'Existing wg0 has a different Mac peer.' >&2; exit 1; }
test "$(wg show wg0 listen-port)" = "$port"
wg show wg0 public-key
