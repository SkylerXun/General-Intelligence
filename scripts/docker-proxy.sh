#!/usr/bin/env bash
# Configure Docker daemon HTTP proxy to reach the Windows host's Clash proxy
# via the WSL2 NAT gateway. The gateway IP may change across WSL restarts,
# so resolve it dynamically on each run.
set -euo pipefail

GW="$(ip route show default | awk '{print $3}')"
if [[ -z "$GW" ]]; then
  echo "ERROR: cannot resolve WSL gateway IP" >&2
  exit 1
fi
echo "Gateway: $GW"

DROPIN="/etc/systemd/system/docker.service.d"
CONF="$DROPIN/http-proxy.conf"
mkdir -p "$DROPIN"

cat > "$CONF" <<EOF
[Service]
Environment="HTTP_PROXY=http://${GW}:7897"
Environment="HTTPS_PROXY=http://${GW}:7897"
Environment="NO_PROXY=localhost,127.0.0.1,::1"
EOF

echo "Wrote $CONF"
cat "$CONF"

echo ""
echo "Reloading systemd and restarting docker..."
systemctl daemon-reload
systemctl restart docker
sleep 3
echo ""
echo "Docker restart status:"
systemctl is-active docker
