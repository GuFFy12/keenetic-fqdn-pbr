#!/opt/bin/busybox sh
set -euo pipefail
IFS=$'\n\t'

if [ "$type" != iptables ] || [ "$table" != mangle ]; then
	exit 0
fi

FQDN_PBR_BASE="${FQDN_PBR_BASE:-/opt/fqdn-pbr}"
SCRIPT="${SCRIPT:-"$FQDN_PBR_BASE/fqdn-pbr.sh"}"

"$SCRIPT" iptables_apply_rules >/dev/null 2>&1
