#!/opt/bin/busybox sh
set -euo pipefail
IFS=$'\n\t'

FQDN_PBR_BASE="${FQDN_PBR_BASE:-/opt/fqdn-pbr}"
FQDN_PBR_SCRIPT="${FQDN_PBR_SCRIPT:-"$FQDN_PBR_BASE/fqdn-pbr.sh"}"
. "$FQDN_PBR_BASE/config.conf"

if [ "$system_name" != "$INTERFACE_WAN" ] || [ "$layer" != link ]; then
	exit 0
fi

if [ "$level" = running ]; then
	"$FQDN_PBR_SCRIPT" ip_route_blackhole_unapply >/dev/null
	"$FQDN_PBR_SCRIPT" ip_route_interface_apply >/dev/null
elif [ "$KILL_SWITCH" = 1 ]; then
	"$FQDN_PBR_SCRIPT" ip_route_blackhole_apply >/dev/null
fi
