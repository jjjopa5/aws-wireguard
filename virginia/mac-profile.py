#!/usr/bin/env python3
"""Create or refresh the local Virginia split profile from the repository's route list."""
import argparse
import base64
import configparser
import ipaddress
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--public-key", action="store_true", help="initialize the client key and print its public key")
parser.add_argument("--endpoint", help="IPv4:port of the Virginia server")
parser.add_argument("--server-key", help="public key of the Virginia server")
args = parser.parse_args()
if bool(args.endpoint) != bool(args.server_key):
    parser.error("--endpoint and --server-key must be supplied together")

os.umask(0o077)
folder = Path.home() / ".config" / "wireguard" / "virginia"
folder.mkdir(parents=True, exist_ok=True, mode=0o700)
key = folder / "client.key"
profile = folder / "virginia.conf"
if not key.exists():
    if profile.exists():
        parser.error("client.key is missing beside an existing profile")
    with tempfile.NamedTemporaryFile(dir=folder) as candidate:
        subprocess.run(["wg", "genkey"], stdout=candidate, check=True)
        try:
            os.link(candidate.name, key)
        except FileExistsError:
            pass
if args.public_key:
    with key.open("rb") as private:
        subprocess.run(["wg", "pubkey"], stdin=private, check=True)
    raise SystemExit

if args.endpoint:
    endpoint, server = args.endpoint, args.server_key
else:
    saved = configparser.ConfigParser()
    if not saved.read(profile):
        parser.error("supply --endpoint and --server-key on first setup")
    endpoint, server = saved["Peer"]["Endpoint"], saved["Peer"]["PublicKey"]
host, sep, port = endpoint.rpartition(":")
if not (sep and port.isdigit() and 0 < int(port) < 65536 and ipaddress.IPv4Address(host)):
    parser.error("invalid IPv4 endpoint")
if len(base64.b64decode(server, validate=True)) != 32:
    parser.error("invalid server public key")

routes = []
source = Path(__file__).resolve().parents[1] / "vpn-routes-virginia.txt"
for line in source.read_text().splitlines():
    value = line.partition("#")[0].strip()
    if value:
        network = ipaddress.ip_network(value)
        if network.prefixlen == 0:
            parser.error("default routes are incompatible with this split profile")
        if network not in routes:
            routes.append(network)
if not routes:
    parser.error("empty route list")
with tempfile.NamedTemporaryFile(mode="w", dir=folder, delete=False) as output:
    output.write(f"""[Interface]
PrivateKey = {key.read_text().strip()}
Address = 10.9.0.2/32, fd00:9::2/128

[Peer]
PublicKey = {server}
Endpoint = {endpoint}
AllowedIPs = {", ".join(map(str, routes))}
PersistentKeepalive = 25
""")
os.replace(output.name, profile)
print(profile)
