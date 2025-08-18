#!/opt/bin/busybox sh
set -euo pipefail
IFS=$'\n\t'

FQDN_PBR_BASE="${FQDN_PBR_BASE:-/opt/fqdn-pbr}"
IPSET_TABLE_RULES_FILE="${IPSET_TABLE_RULES_FILE:-"$FQDN_PBR_BASE/ipset_$IPSET_TABLE.rules"}"

ipset_create() {
	ipset create -exist "$IPSET_TABLE" hash:ip timeout "$IPSET_TABLE_TIMEOUT" || true
}

ipset_destroy() {
	ipset destroy "$IPSET_TABLE" || true
}

ipset_save() {
	ipset save "$IPSET_TABLE" | tail -n +2 >"$IPSET_TABLE_RULES_FILE" || true
}

ipset_restore() {
	ipset restore -exist <"$IPSET_TABLE_RULES_FILE" || true
}

iptables_rule_do() {
    local op="$1"; shift
    local builder="$1"; shift

    "$builder" "$@" | xargs -0 -r iptables -w -t mangle "$op"
}

iptables_rule_check() {
	iptables_rule_do -C "$@" >/dev/null 2>&1
}

iptables_rule_add() {
	iptables_rule_check "$@" || iptables_rule_do -A "$@"
}

iptables_rule_delete() {
	iptables_rule_do -D "$@";
}

build_rule_set_mark() {
	printf '%s\0' PREROUTING -s "$1" -m conntrack --ctstate NEW -m set --match-set "$2" dst -j CONNMARK --set-mark "$3"
}

build_rule_restore_mark() {
	printf '%s\0' PREROUTING -s "$1" -m set --match-set "$2" dst -j CONNMARK --restore-mark
}

iptables_apply_rules() {
	old_ifs="$IFS"
	IFS=' '
	for interface_lan_subnet in $INTERFACE_LAN_SUBNETS; do
		iptables_rule_add build_rule_set_mark "$interface_lan_subnet" "$IPSET_TABLE" "$MARK" || true
        iptables_rule_add build_rule_restore_mark "$interface_lan_subnet" "$IPSET_TABLE" || true
	done
	IFS="$old_ifs"
}

iptables_unapply_rules() {
	old_ifs="$IFS"
	IFS=' '
	for interface_lan_subnet in $INTERFACE_LAN_SUBNETS; do
		iptables_rule_delete build_rule_set_mark "$interface_lan_subnet" "$IPSET_TABLE" "$MARK" || true
		iptables_rule_delete build_rule_restore_mark "$interface_lan_subnet" "$IPSET_TABLE" || true
	done
	IFS="$old_ifs"
}

ip_rule_exists() {
	ip rule list | grep -qw "from all fwmark $(printf "0x%x" "$1") lookup $1"
}

ip_rule_apply() {
	ip_rule_exists "$MARK" || ip rule add fwmark "$MARK" table "$MARK" || true
}

ip_rule_unapply() {
	ip rule del fwmark "$MARK" table "$MARK" || true
}

ip_route_blackhole_apply() {
	ip route add blackhole default table "$MARK" 2>/dev/null || true
}

ip_route_blackhole_unapply() {
	ip route del blackhole default table "$MARK" || true
}

ip_route_interface_apply() {
	ip route replace default dev "$INTERFACE_WAN" table "$MARK" || true
}

ip_route_interface_unapply() {
	ip route del default dev "$INTERFACE_WAN" table "$MARK" || true
}
