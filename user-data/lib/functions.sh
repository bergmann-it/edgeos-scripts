#!/bin/sh
iface_from_path(){
  iface_config_path=$1
  iface_num=$(echo "${iface_config_path}" | rev | cut -d '/' -f 1 | rev)
  iface_type=$(echo "${iface_config_path}" | rev | cut -d '/' -f 2 | rev)
  iface_parent=$(echo "${iface_config_path}" | rev | cut -d '/' -f 3 | rev)
  if [ "${iface_type}" = "ethernet" ]; then
    iface="${iface_num}"
  elif [ "${iface_type}" = "vif" ]; then
    iface="${iface_parent}.${iface_num}"
  elif [ "${iface_type}" = "pppoe" ]; then
    iface="${iface_type}${iface_num}"
  else
    echo "interface type ${iface_type} not supported" >&2
    return 1
  fi
  echo $iface
}

path_from_iface(){
  iface=$1
  iface_string=$iface
  case $iface in
    eth*)
      iface_string=$iface
      ;;
    pppoe* )
      iface_num=$(echo $iface | cut -c 6-)
      iface_string="pppoe/${iface_num}"
      ;;
    *.*)
      baseif=$(echo $iface | cut -d . -f 1)
      vif=$(echo $iface | cut -d . -f 2)
      iface_string="$(path_from_iface $baseif)/vif/${vif}"
      ;;
    *)
      echo "interface type of ${iface} not supported"
      exit 1
      ;;
  esac
  iface_config_path=$(find /opt/vyatta/config/active/interfaces | egrep "${iface_string}\$" | head -n 1 )
  #read data from config
  if [ -z "$iface_config_path" ]; then
    echo "could not find interface config" >&2
    exit 1
  fi
  echo $iface_config_path
}

pd_prefix(){
  iface=$1
  id=$2
  prefix_len=$3

  if echo "$1" | grep -Eq '^[0-9a-f]+$'; then
    iface=""
    id=$1
    prefix_len=$2
  fi

  if [ -z "$id" ]; then
    id=0
  fi
  
  if [ -z "$iface" ]; then
    pd_config_path=$(find /opt/vyatta/config/active/interfaces | egrep '/dhcpv6-pd/pd/[0-9]+$' | head -n 1)
    iface_config_path=$(echo "$pd_config_path" | rev | cut -d '/' -f 4- | rev)
    iface=$(iface_from_path $iface_config_path)
  fi

  iface_config_path=$(path_from_iface $iface)
  if [ -z "$iface_config_path" ]; then
    echo "could not find iface $iface" >&2
    exit 1
  fi

  pd_config_path=$(find ${iface_config_path} | egrep '/dhcpv6-pd/pd/[0-9]+$' | head -n 1)
  if ! [ -d "${pd_config_path}" ]; then
    echo "pd not configured for interface" >&2
    exit 1
  fi
  pd_prefix_length=$(cat ${pd_config_path}/prefix-length/node.val)
  pd_first_iface=$(ls ${pd_config_path}/interface | head -n 1)
  if [ -z "$pd_first_iface" ]; then
    echo "no internal interface configured for PD" >&2
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

  if [ -z "${prefix_len}" ]; then
    if [ $(printf '%d' 0x$id) -gt 0 ]; then
      prefix_len=64
    else
      prefix_len=$pd_prefix_length
    fi
  fi
  
  echo "${full_parts_prefix}:${prefix_chars}$(printf "%0${id_char_count}x" 0x$id)::/${prefix_len}"
}
