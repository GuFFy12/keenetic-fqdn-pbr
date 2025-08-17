#!/opt/bin/busybox sh
set -euo pipefail
IFS=$'\n\t'

FQDN_PBR_BASE="${FQDN_PBR_BASE:-/opt/fqdn-pbr}"
IPSET_TABLE_RULES_FILE="${IPSET_TABLE_RULES_FILE:-"$FQDN_PBR_BASE/ipset_$IPSET_TABLE.rules"}"

ipset_exists() {
	ipset -q list "$1" >/dev/null
}

ipset_in_use() {
	iptables-save | grep -qw "\--match-set blocklist"
}

ipset_create() {
	if ! ipset_exists "$IPSET_TABLE"; then
		ipset create "$IPSET_TABLE" hash:ip timeout "$IPSET_TABLE_TIMEOUT"
		echo "Created ipset $IPSET_TABLE"
	fi
}

ipset_destroy() {
	if ipset_in_use "$IPSET_TABLE"; then
		echo "Cannot destroy ipset $IPSET_TABLE: iptables rules exist" >&2
		return 1
	elif ipset_exists "$IPSET_TABLE"; then
		ipset destroy "$IPSET_TABLE"
		echo "Destroyed ipset $IPSET_TABLE"
	fi
}

ipset_save() {
	if ! ipset_exists "$IPSET_TABLE"; then
		echo "Cannot save ipset $IPSET_TABLE: ipset does not exist" >&2
		return 1
	fi
	ipset save "$IPSET_TABLE" | tail -n +2 >"$IPSET_TABLE_RULES_FILE"
	echo "Saved ipset $IPSET_TABLE"
}

ipset_restore() {
	if ! ipset_exists "$IPSET_TABLE"; then
		echo "Cannot restore ipset $IPSET_TABLE: ipset does not exist" >&2
		return 1
	elif [ -f "$IPSET_TABLE_RULES_FILE" ]; then
		ipset restore -exist <"$IPSET_TABLE_RULES_FILE"
		echo "Restored ipset $IPSET_TABLE"
	fi
}

iptables_rule_do() {
    local op="$1"; shift
    local builder="$1"; shift
    # Превращаем вывод builder'а (по одному токену на строке) в "$@"
    # Важно: токены не должны содержать пробелов — у нас их и нет.
    # shellcheck disable=SC2046
    "$builder" "$@" | xargs -0 -r iptables "$op"
}

iptables_rule_add() {
	if ! iptables_rule_do -C "$@" >/dev/null 2>&1; then 
		iptables_rule_do -A "$@"; 
	fi
}

iptables_rule_delete() {
	if iptables_rule_do -C "$@" >/dev/null 2>&1; then 
		iptables_rule_do -D "$@"; 
	fi
}

build_rule_set_mark() {
	printf '%s\0' PREROUTING -w -t mangle -s "$1" -m conntrack --ctstate NEW -m set --match-set "$2" dst -j CONNMARK --set-mark "$3"
}

build_rule_restore_mark() {
	printf '%s\0' PREROUTING -w -t mangle -s "$1" -m set --match-set "$2" dst -j CONNMARK --restore-mark
}

iptables_apply_rules() {
	if ! ipset_exists "$IPSET_TABLE"; then
		echo "Cannot apply iptables rules: ipset $IPSET_TABLE does not exist" >&2
		return 1
	fi
	echo "Applying iptables rules for ipset $IPSET_TABLE and mark $MARK"
	old_ifs="$IFS"
	IFS=' '
	for interface_lan_subnet in $INTERFACE_LAN_SUBNETS; do
		iptables_rule_add build_rule_set_mark "$interface_lan_subnet" "$IPSET_TABLE" "$MARK"
        iptables_rule_add build_rule_restore_mark "$interface_lan_subnet" "$IPSET_TABLE"
		echo "Applied iptables rules for interface lan subnet $interface_lan_subnet"
	done
	IFS="$old_ifs"
}

iptables_unapply_rules() {
	echo "Unapplying iptables rules for ipset $IPSET_TABLE and mark $MARK"
	old_ifs="$IFS"
	IFS=' '
	for interface_lan_subnet in $INTERFACE_LAN_SUBNETS; do
		iptables_rule_delete build_rule_set_mark "$interface_lan_subnet" "$IPSET_TABLE" "$MARK"
		iptables_rule_delete build_rule_restore_mark "$interface_lan_subnet" "$IPSET_TABLE"
		echo "Unapplied iptables rules for interface lan subnet $interface_lan_subnet"
	done
	IFS="$old_ifs"
}

ip_rule_exists() {
	ip rule list | grep -qw "from all fwmark $(printf "0x%x" "$1") lookup $1"
}

ip_rule_apply() {
	if ! ip_rule_exists "$MARK"; then
		ip rule add fwmark "$MARK" table "$MARK"
		echo "Applied ip rule $MARK"
	fi
}

ip_rule_unapply() {
	if ip_rule_exists "$MARK"; then
		ip rule del fwmark "$MARK" table "$MARK"
		echo "Unapplied ip rule $MARK"
	fi
}

ip_route_exists() {
	ip route list table "$1" | grep -q "^${2:-.}"
}

ip_route_blackhole_exists() {
	ip_route_exists "$1" "blackhole default"
}

ip_route_dev_exists() {
	ip_route_exists "$1" "default dev $2"
}

ip_link_up() {
	[ -n "$(ip link show "$1" up)" ]
}

ip_route_blackhole_apply() {
	if ! ip_route_exists "$MARK"; then
		ip route add blackhole default table "$MARK"
		echo "Applied ip route blackhole $MARK"
	fi
}

ip_route_blackhole_unapply() {
	if ip_route_blackhole_exists "$MARK"; then
		ip route del blackhole default table "$MARK"
		echo "Unapplied ip route blackhole $MARK"
	fi
}

ip_route_interface_apply() {
	old_ifs="$IFS"
	IFS=' '
	for interface_wan in $INTERFACE_WAN; do
		if ! ip_link_up "$interface_wan"; then
			echo "Cannot apply ip route $MARK: interface wan $interface_wan is down" >&2
			return 1
		elif ! ip_route_exists "$MARK"; then
			ip route add default dev "$interface_wan" table "$MARK"
			echo "Applied ip route $MARK to interface wan $interface_wan"
		fi
	done
	IFS="$old_ifs"
}

ip_route_interface_unapply() {
	old_ifs="$IFS"
	IFS=' '
	for interface_wan in $INTERFACE_WAN; do
		if ip_route_dev_exists "$MARK" "$interface_wan"; then
			ip route del default dev "$interface_wan" table "$MARK"
			echo "Unapplied ip route $MARK to interface wan $interface_wan"
		fi
	done
	IFS="$old_ifs"
}
