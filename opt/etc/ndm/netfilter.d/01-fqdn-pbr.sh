#!/opt/bin/busybox sh
set -euo pipefail
IFS=$'\n\t'

if [ "$type" != iptables ] || [ "$table" != mangle ]; then
	exit 0
fi

FQDN_PBR_BASE="${FQDN_PBR_BASE:-/opt/fqdn-pbr}"
FQDN_PBR_SCRIPT="${FQDN_PBR_SCRIPT:-"$FQDN_PBR_BASE/fqdn-pbr.sh"}"
. "$FQDN_PBR_BASE/config.conf"

"$FQDN_PBR_SCRIPT" iptables_apply_rules >/dev/null
