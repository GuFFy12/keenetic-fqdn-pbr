#!/opt/bin/busybox sh
set -euo pipefail
IFS=$'\n\t'

SCRIPT="$(readlink -f "$0")"
FQDN_PBR_BASE="$(dirname "$SCRIPT")"
. "$FQDN_PBR_BASE/config.conf"
. "$FQDN_PBR_BASE/functions.sh"

do_start() {
	ipset_create
	if [ "$IPSET_TABLE_SAVE" = "1" ]; then
		ipset_restore
	fi
	iptables_apply_rules
	ip_rule_apply
	ip_route_interface_apply
	if [ "$KILL_SWITCH" = "1" ]; then
		ip_route_blackhole_apply
	fi

	echo FQDN PBR started
}

do_stop() {
	ip_rule_unapply
	iptables_unapply_rules
	if [ "$IPSET_TABLE_SAVE" = "1" ]; then
		ipset_save
	fi
	ipset_destroy

	echo FQDN PBR stopped
}

validate_config() {
	# Minimalist variable validation relying on 'set -u' to catch unset vars.
	# ':' is a no-op used to expand all required variables and trigger an error if any are missing.
	: "$KILL_SWITCH" "$IPSET_TABLE_SAVE" "$IPSET_TABLE" "$IPSET_TABLE_TIMEOUT" \
    "$INTERFACE_LAN" "$INTERFACE_WAN" "$INTERFACE_WAN_SUBNET" "$MARK"
}

usage() {
	echo "Usage: $SCRIPT <start|stop|restart|save|restore>" >&2
	exit 1
}

validate_config
if [ "$#" -ne 1 ]; then
	usage
fi
case "$1" in
start)
	do_start
	;;

stop)
	do_stop
	;;

restart)
	do_stop
	do_start
	;;

save)
	ipset_save
	;;

restore)
	ipset_restore
	;;

# region NDM hooks
iptables_apply_rules)
	iptables_apply_rules
	;;

ip_route_blackhole_apply)
	ip_route_blackhole_apply
	;;

ip_route_blackhole_unapply)
	ip_route_blackhole_unapply
	;;

ip_route_interface_apply)
	ip_route_interface_apply
	;;
# endregion

*)
	usage
	;;
esac
