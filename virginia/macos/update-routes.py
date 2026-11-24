"""Update the system Virginia profile using only validated CIDRs from GitHub."""
import fcntl
import ipaddress
import os
from pathlib import Path
import re
import subprocess
import tempfile

CONFIG = Path("/etc/wireguard/virginia.conf")
URL = "https://raw.githubusercontent.com/jjjopa5/aws-wireguard/main/vpn-routes-virginia.txt"
QUICK = "/opt/homebrew/bin/wg-quick"


def parse_routes(text):
    networks = []
    for line in text.splitlines():
        cidr = line.partition("#")[0].strip()
        if not cidr:
            continue
        net = ipaddress.ip_network(cidr)
        if not net.prefixlen:
            raise ValueError("default route in split list")
        if net not in networks:
            networks.append(net)
    if not networks:
        raise ValueError("empty route list")
    return ", ".join(map(str, networks))


def replace_file(content):
    with tempfile.NamedTemporaryFile(mode="w", dir=CONFIG.parent, delete=False) as tmp:
        tmp.write(content)
    os.replace(tmp.name, CONFIG)


def update():
    fetched = subprocess.check_output([
        "/usr/bin/curl", "--proto", "=https", "--fail", "--silent", "--show-error",
        "--max-time", "30", "--max-filesize", "131072", URL,
    ], text=True)
    routes = parse_routes(fetched)
    old = CONFIG.read_text()
    new, count = re.subn(r"(?m)^AllowedIPs[ \t]*=[^\n]*$", "AllowedIPs = " + routes, old)
    if count != 1:
        raise ValueError("expected one Virginia peer")
    if old == new:
        return
    active = Path("/var/run/wireguard/virginia.name").exists()
    if active:
        subprocess.run([QUICK, "down", "virginia"], check=True)
    try:
        replace_file(new)
        if active:
            subprocess.run([QUICK, "up", "virginia"], check=True)
    except Exception:
        replace_file(old)
        if active:
            subprocess.run([QUICK, "up", "virginia"], check=True)
        raise


if __name__ == "__main__":
    os.umask(0o077)
    os.environ["PATH"] = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    with (CONFIG.parent / ".virginia-routes.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        update()
