#!/bin/sh
set -e

source /config/user-data/lib/functions.sh

prefix=$(pd_prefix pppoe0 c0 58)

ip6tables -t nat -F POSTROUTING
ip6tables -t nat -A POSTROUTING -o pppoe0 -s fd6b:b175:9ccf:00c0::/58 -j NETMAP --to $prefix -m comment --comment 'ntpv6_out'
ip6tables -t nat -F PREROUTING
ip6tables -t nat -A PREROUTING -i pppoe0 -d $prefix -j NETMAP --to fd6b:b175:9ccf:00c0::/58  -m comment --comment 'ntpv6_in'
ip6tables -t raw -D OUTPUT -j NOTRACK
ip6tables -t raw -D PREROUTING -j NOTRACK
