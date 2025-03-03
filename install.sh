#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

RELEASE_TAG=v1.0.0

DNSMASQ_ROUTING_BASE="${DNSMASQ_ROUTING_BASE:-/opt/dnsmasq_routing}"
DNSMASQ_ROUTING_SCRIPT="${DNSMASQ_ROUTING_SCRIPT:-"$DNSMASQ_ROUTING_BASE/dnsmasq_routing.sh"}"
DNSMASQ_ROUTING_CONFIG="${DNSMASQ_ROUTING_CONFIG:-"$DNSMASQ_ROUTING_BASE/dnsmasq_routing.conf"}"
DNSMASQ_CONFIG="${DNSMASQ_CONFIG:-/opt/etc/dnsmasq.conf}"

DNS_OVER_HTTPS_URL="${DNS_OVER_HTTPS_URL:-https://dns.google/dns-query}"

ask_yes_no() {
	while true; do
		echo "$1 (Y/N): "
		read -r answer

		case "$answer" in
		[yY1]) return 0 ;;
		[nN0]) return 1 ;;
		*) echo Invalid choice ;;
		esac
	done
}

select_number() {
	while true; do
		counter=1
		echo "$1" | while IFS= read -r line; do
			echo "$counter: $line"
			counter=$((counter + 1))
		done

		read -r choice

		selected_line="$(echo "$1" | sed -n "${choice}p")"
		if [ -n "$selected_line" ]; then
			return 0
		fi
		echo Invalid choice
	done
}

set_config_value() {
	sed -i "s|^$2=.*|$2=$3|" "$1"
}

add_cron_job() {
	if ! crontab -l 2>/dev/null | grep -Fq "$2"; then
		(
			crontab -l 2>/dev/null
			echo "$1 $2"
		) | crontab -
	fi
}

rm_dir() {
	if [ -d "$1" ]; then
		rm -r "$1"
	fi
}

delete_service() {
	if [ -f "$2" ] && ! "$2" stop; then
		echo "Failed to stop service using script: $2" >&2
	fi
	rm_dir "$1"
}

get_dnsmasq_config_server() {
	ndmc -c dns-proxy https upstream "$DNS_OVER_HTTPS_URL"

	DNSMASQ_CONFIG_SERVER="${DNSMASQ_CONFIG_SERVER:-"127.0.0.1#$(awk '$1 == "127.0.0.1" {print $2; exit}' /tmp/ndnproxymain.stat)"}"

	if [ -z "$DNSMASQ_CONFIG_SERVER" ]; then
		return 1
	fi
}

select_dnsmasq_routing_interface() {
	interfaces="$(ip -o -4 addr show | awk '{print $2, $4}')"

	echo Interface list:
	select_number "$interfaces"

	DNSMASQ_ROUTING_CONFIG_INTERFACE="$($selected_line | awk '{print $2}')"
	DNSMASQ_ROUTING_CONFIG_INTERFACE_SUBNET="$($selected_line | awk '{print $3}')"
}

if ! command -v ndmc >/dev/null; then
	echo Command 'ndmc' not found >&2
	exit 1
elif ! NDM_VERSION="$(ndmc -c show version | grep -w title | head -n 1 | awk '{print $2}' | tr -cd '0-9.')"; then
	echo Failed to retrieve NDM version >&2
	exit 1
elif [ -z "$NDM_VERSION" ]; then
	echo Invalid or missing NDM version >&2
	exit 1
elif [ "${NDM_VERSION%%.*}" -lt 4 ]; then
	# ndm/iflayerchanged.d does not exist in versions below 4.0.0
	echo "NDM version $NDM_VERSION is less than 4.0.0" >&2
	exit 1
fi

echo Installing packages...
opkg update && opkg install cron dnsmasq grep ipset iptables

echo Installing Dnsmasq Routing...
delete_service "$DNSMASQ_ROUTING_BASE" "$DNSMASQ_ROUTING_SCRIPT"
if [ -n "$(readlink -f "$0")" ]; then
	cp -r opt/* /opt/
else
	TMP_DIR=$(mktemp -d)
	RELEASE_FILE="keenetic-dnsmasq-routing-$RELEASE_TAG.tar.gz"

	curl -f -L -o "$TMP_DIR/$RELEASE_FILE" "https://github.com/GuFFy12/keenetic-dnsmasq-routing/releases/download/$RELEASE_TAG/$RELEASE_FILE"
	tar -xvzf "$TMP_DIR/$RELEASE_FILE" -C "$TMP_DIR" >/dev/null
	cp -r "$TMP_DIR/opt/"* /opt/
	rm -rf "$TMP_DIR"
fi

echo Changing the settings...
if ! get_dnsmasq_config_server; then
	echo Failed to retrieve DNS server for dnsmasq >&2
	exit 1
fi
select_dnsmasq_routing_interface

set_config_value "$DNSMASQ_CONFIG" "server" "$DNSMASQ_CONFIG_SERVER"
set_config_value "$DNSMASQ_ROUTING_CONFIG" "INTERFACE" "$DNSMASQ_ROUTING_CONFIG_INTERFACE"
set_config_value "$DNSMASQ_ROUTING_CONFIG" "INTERFACE_SUBNET" "$DNSMASQ_ROUTING_CONFIG_INTERFACE_SUBNET"

if ask_yes_no "Create cron job to auto save dnsmasq ipset?"; then
	add_cron_job "0 0 * * *" "$DNSMASQ_ROUTING_SCRIPT save"
fi

echo Running dnsmasq routing...
"$DNSMASQ_ROUTING_SCRIPT" start

echo Dnsmasq Routing have been successfully installed. For further configuration please refer to README.md file!
