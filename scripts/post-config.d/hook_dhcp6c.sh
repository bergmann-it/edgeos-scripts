#!/bin/sh

#modify dhcp6c reply script

cp /config/user-data/dhcp6c/ubnt-dhcp6c-script /opt/vyatta/sbin/ubnt-dhcp6c-script
chmod 755 /opt/vyatta/sbin/ubnt-dhcp6c-script
