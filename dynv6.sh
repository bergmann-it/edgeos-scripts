#!/bin/sh
set -e

ddns_config_path="/opt/vyatta/config/active/service/dns/dynamic/interface"

iface=$1
if [ -z "$iface" ]; then
  #use first ddns interface if not given by argument
  iface=$(ls ${ddns_config_path} | head -n 1)
fi
base_url="https://dynv6.com/api/update"

case $iface in
  pppoe* )
    iface_type=pppoe
    iface_num=$(echo $iface | cut -c 6-)
    ;;
  *)
    echo "interface type not supported"
    exit 1
    ;;
esac

#read data from config
iface_config_path=$(find /opt/vyatta/config/active/interfaces/ | grep "${iface_type}/${iface_num}\$")
if [ -z "$iface_config_path" ]; then
  echo "could not find interace config"
  exit 1
fi
ddns_iface_config_path="${ddns_config_path}/$iface/service"
ddns_first_config=$(ls ${ddns_iface_config_path} | head -n 1)
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
pd_config_path="${iface_config_path}/dhcpv6-pd/pd/0"
if ! [ -d "${pd_config_path}" ]; then
  echo "pd not configured for interface"
  exit 1
fi
pd_prefix_length=$(cat ${pd_config_path}/prefix-length/node.val)
pd_first_iface=$(ls ${pd_config_path}/interface | head -n 1)
if [ -z "$pd_first_iface" ]; then
  echo "no internal interface configured for PD"
  exit 1
fi
pd_first_iface_prefix_id=$(cat "${pd_config_path}/interface/${pd_first_iface}/prefix-id/node.val")

# get configured prefix of first interface
first_iface_prefix=$(ip -6 addr show dev ${pd_first_iface} scope global | awk '/inet6/{print $2}')

# calculate full prefix
full_prefix_parts=$((pd_prefix_length/16))
prefix_char_count=$(((pd_prefix_length%16)/4))
id_char_count=$((4-${prefix_char_count}))
full_parts_prefix=$(echo ${first_iface_prefix} | cut -d : -f 1-${full_prefix_parts})
prefix_chars="" 
id_chars=$(echo ${first_iface_prefix} | cut -d : -f $((full_prefix_parts+1)))
if [ ${prefix_char_count} -gt 0 ]; then
  prefix_chars=$(echo ${id_chars} | cut -c 1-${prefix_char_count})
  id_chars=$(echo ${id_chars} | cut -c $((prefix_char_count+1))-)
fi;

ipv6prefix="${full_parts_prefix}:${prefix_chars}$(printf "%0${id_char_count}d" 0)::"
ipv6=$(ip -6 addr show dev $iface scope global | awk '/inet6/{print $2}' | cut -d '/' -f 1)

#update Data
curl -G -s -o /dev/null \
  --data "token=${token}" \
  --data "zone=${zone}" \
  --data "ipv6=${ipv6}" \
  --data "ipv6prefix=${ipv6prefix}" \
  "${base_url}" 
