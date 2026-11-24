#!/bin/bash
# Run on the owner's Mac with sudo; the first argument is the generated client profile.
set -euo pipefail
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
umask 077
[[ $EUID == 0 ]] || { echo "Run with sudo." >&2; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)
profile=${1:?Pass the path to the prepared virginia.conf}
owner=$(stat -f %Su /dev/console)
owner_uid=$(id -u "$owner")
[[ $owner_uid -ge 501 && -f $profile ]]
cfg=/etc/wireguard/virginia.conf
old_boot=com.wireguard.wg0
old_routes=com.vpn.update-routes
boot=com.wireguard.virginia
routes=com.vpn.update-routes-virginia
daemon=/Library/LaunchDaemons
quick=/opt/homebrew/bin/wg-quick
userctl() { launchctl asuser "$owner_uid" /usr/bin/sudo -u "$owner" /bin/launchctl "$@"; }
unload() { if launchctl print "$1" >/dev/null 2>&1; then launchctl bootout "$1"; fi; }
for label in "$boot" "$routes"; do plutil -lint "$here/$label.plist"; done
staged=$(mktemp /etc/wireguard/.virginia.XXXXXXXX)
trap 'rm -f "$staged"' EXIT
install -m 600 -o root -g wheel "$profile" "$staged"
# wg-quick supports root shell hooks. Accept only keys from the generated split profile.
probe=$(/usr/bin/python3 -I - "$staged" <<'PY'
import base64, configparser, ipaddress, sys
c = configparser.ConfigParser(interpolation=None, strict=True)
c.read(sys.argv[1])
def require(ok):
    if not ok:
        raise SystemExit("Unsupported Virginia profile")
require(c.sections() == ["Interface", "Peer"] and not c.defaults())
require(set(c["Interface"]) == {"privatekey","address"})
require(set(c["Peer"]) == {"publickey","endpoint","allowedips","persistentkeepalive"})
require(all("\n" not in v for section in c.sections() for v in c[section].values()))
require(c["Peer"]["Endpoint"] == "23.23.214.1:51820")
require(c["Peer"]["PersistentKeepalive"] == "25")
require(c["Interface"]["Address"] == "10.9.0.2/32, fd00:9::2/128")
for section, key in [("Interface","PrivateKey"), ("Peer","PublicKey")]:
    require(len(base64.b64decode(c[section][key],validate=True)) == 32)
networks = [ipaddress.ip_network(v.strip()) for v in c["Peer"]["AllowedIPs"].split(",")]
require(all(n.prefixlen for n in networks))
print(next(iter(networks[0].hosts()), networks[0].network_address))
PY
)
mv -f "$staged" "$cfg"
install -m 644 -o root -g wheel "$here/update-routes.py" /etc/wireguard/update-routes-virginia.py
for label in "$boot" "$routes"; do install -m 644 -o root -g wheel "$here/$label.plist" "$daemon/$label.plist"; done
unload "system/$routes"
unload "system/$boot"
had_virginia=0
had_eu=0
if [[ -f /var/run/wireguard/wg0.name ]]; then had_eu=1; "$quick" down wg0; fi
if [[ -f /var/run/wireguard/virginia.name ]]; then had_virginia=1; "$quick" down virginia; fi
recover() {
    echo "Virginia setup failed; restoring the previous running tunnel." >&2
    unload "system/$boot" || true
    if [[ -f /var/run/wireguard/virginia.name ]]; then "$quick" down virginia || true; fi
    if [[ $had_eu == 1 ]]; then "$quick" up wg0; elif [[ $had_virginia == 1 ]]; then "$quick" up virginia; fi
}
trap recover ERR
launchctl enable "system/$boot"
launchctl bootstrap system "$daemon/$boot.plist"
for _ in {1..30}; do
    if [[ -s /var/run/wireguard/virginia.name ]]; then
        iface=$(cat /var/run/wireguard/virginia.name)
        if /opt/homebrew/bin/wg show "$iface" endpoints | grep -Fq '23.23.214.1:51820' &&
           route -n get "$probe" | grep -Fq "interface: $iface"; then break; fi
    fi
    sleep 1
done
/opt/homebrew/bin/wg show "$iface" endpoints | grep -F '23.23.214.1:51820'
route -n get "$probe" | grep -F "interface: $iface"
launchctl enable "system/$routes"
launchctl bootstrap system "$daemon/$routes.plist"
trap - ERR
userctl disable "gui/$owner_uid/$old_routes"
if userctl print "gui/$owner_uid/$old_routes" >/dev/null 2>&1; then userctl bootout "gui/$owner_uid/$old_routes"; fi
launchctl disable "system/$old_boot"
unload "system/$old_boot"
echo "Virginia active ($iface); old Frankfurt jobs disabled."
