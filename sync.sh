#!/bin/bash
# Syncs Pi-hole config to this repo, scrubbing credentials before commit.
# Run with: bash sync.sh
# Requires sudo for pihole-group files.

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"

echo "==> Syncing Pi-hole config to $REPO"

# --- pihole.toml (scrub password hashes) ---
echo "  pihole.toml"
sudo cp /etc/pihole/pihole.toml "$REPO/pihole.toml"
sudo chown pi:pi "$REPO/pihole.toml"
# Blank credential fields and remove ### CHANGED annotations on those lines
sed -i \
  -e 's/^\(\s*pwhash\s*=\s*\).*$/\1""/' \
  -e 's/^\(\s*totp_secret\s*=\s*\).*$/\1""/' \
  -e 's/^\(\s*app_pwhash\s*=\s*\).*$/\1""/' \
  "$REPO/pihole.toml"

# --- dnsmasq.conf ---
echo "  dnsmasq.conf"
sudo cp /etc/pihole/dnsmasq.conf "$REPO/dnsmasq.conf"
sudo chown pi:pi "$REPO/dnsmasq.conf"

# --- dns-servers.conf ---
echo "  dns-servers.conf"
sudo cp /etc/pihole/dns-servers.conf "$REPO/dns-servers.conf"
sudo chown pi:pi "$REPO/dns-servers.conf"

# --- logrotate ---
echo "  logrotate"
sudo cp /etc/pihole/logrotate "$REPO/logrotate"
sudo chown pi:pi "$REPO/logrotate"

# --- custom.list (local DNS entries) ---
echo "  custom.list"
sudo cp /etc/pihole/hosts/custom.list "$REPO/custom.list"
sudo chown pi:pi "$REPO/custom.list"

# --- Export adlists from gravity.db ---
echo "  adlists.txt"
REPO="$REPO" python3 - <<'PYEOF'
import sqlite3, os
repo = os.environ['REPO']
conn = sqlite3.connect('/etc/pihole/gravity.db')
c = conn.cursor()
c.execute('SELECT address, enabled, comment FROM adlist ORDER BY id')
rows = c.fetchall()
conn.close()
with open(f'{repo}/adlists.txt', 'w') as f:
    f.write('# Pi-hole adlists\n')
    f.write('# format: status|url|comment\n\n')
    for address, enabled, comment in rows:
        status = 'enabled' if enabled else 'disabled'
        f.write(f'{status}|{address}|{comment or ""}\n')
print(f'    {len(rows)} adlists exported')
PYEOF

# --- Export domain lists from gravity.db ---
echo "  domain lists"
REPO="$REPO" python3 - <<'PYEOF'
import sqlite3, os
repo = os.environ['REPO']
conn = sqlite3.connect('/etc/pihole/gravity.db')
c = conn.cursor()
type_map = {0: 'allowlist', 1: 'blocklist', 2: 'regex_allowlist', 3: 'regex_blocklist'}
for type_id, name in type_map.items():
    c.execute('SELECT domain, enabled, comment FROM domainlist WHERE type=? ORDER BY domain', (type_id,))
    rows = c.fetchall()
    with open(f'{repo}/{name}.txt', 'w') as f:
        f.write(f'# Pi-hole {name.replace("_", " ")}\n')
        f.write('# format: status|domain|comment\n\n')
        for domain, enabled, comment in rows:
            status = 'enabled' if enabled else 'disabled'
            f.write(f'{status}|{domain}|{comment or ""}\n')
    print(f'    {len(rows)} {name} entries exported')
conn.close()
PYEOF

echo ""
echo "==> Sync complete. Review changes with: git -C $REPO diff"
echo "    Then commit with: git -C $REPO add -A && git -C $REPO commit -m 'chore: sync pihole config'"
