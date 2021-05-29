#!/bin/sh
set -e

source /config/user-data/lib/functions.sh

ddns_config_path="/opt/vyatta/config/active/service/dns/dynamic/interface"
base_url="https://dynv6.com/api/update"

iface=$(ls ${ddns_config_path} | head -n 1)

#read data from config
ddns_iface_config_path="${ddns_config_path}/$iface/service"
ddns_first_config=""
for config in $(ls ${ddns_iface_config_path}); do
  hostname=$(cat "${ddns_iface_config_path}/${config}/host-name/node.val" | tr -d '[:space:]') 
  if [ -n "${hostname}" ]; then
    ddns_first_config=$config
    break
  fi
done
if [ -z "$ddns_first_config" ]; then
  echo "could not find dyndns config"
  exit 1
fi
token=$(cat ${ddns_iface_config_path}/${ddns_first_config}/password/node.val | head -n 1)
if [ -z "$token" ]; then
  echo "could not find token"
  exit 1
fi
zone=$(cat ${ddns_iface_config_path}/${ddns_first_config}/host-name/node.val | head -n 1)
if [ -z "$zone" ]; then
  echo "could not find zone"
  exit 1
fi

ipv6prefix=$(pd_prefix $iface)
ipv6=$(ip -6 addr show dev $iface scope global | awk '/inet6/{print $2}' | cut -d '/' -f 1)
ipv4=$(ip -4 addr show dev $iface scope global | awk '/inet/{print $2}' | cut -d '/' -f 1)

#update Data
curl -G -s -o /dev/null \
  --data "token=${token}" \
  --data "zone=${zone}" \
  --data "ipv4=${ipv4}" \
  --data "ipv6=${ipv6}" \
  --data "ipv6prefix=${ipv6prefix}" \
  "${base_url}" 
