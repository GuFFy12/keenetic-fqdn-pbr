#!/opt/bin/busybox sh
set -euo pipefail
IFS=$'\n\t'

FQDN_PBR_BASE="${FQDN_PBR_BASE:-/opt/fqdn-pbr}"
SCRIPT="${SCRIPT:-"$FQDN_PBR_BASE/fqdn-pbr.sh"}"

if [ "$system_name" != "$INTERFACE" ] || [ "$layer" != link ]; then
	exit 0
fi

if [ "$level" = running ]; then
	"$SCRIPT" ip_route_blackhole_unapply >/dev/null #2>&1 TODO
	"$SCRIPT" ip_route_interface_apply >/dev/null #2>&1
elif [ "$KILL_SWITCH" = 1 ]; then
	"$SCRIPT" ip_route_blackhole_apply >/dev/null #2>&1
fi
