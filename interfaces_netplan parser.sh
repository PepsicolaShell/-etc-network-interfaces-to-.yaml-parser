#!/bin/bash
#no se si queremos que las interfaces se llamen "eth0" por ejemplo o lo que pone
#al lado de "name" (por ejemplo "PCE-Net"). En este script es el primer caso.


#define /etc/network/interfaces route:
interfaces="./interfaces"



#header
echo -e "network:"\
		"\n  version: 2"\
		"\n  renderer: NetworkManager"\
		"\n  ethernets:" > 01-network-manager-all.yaml



#ethernet interfaces:
grep -n "iface eth" $interfaces | while IFS=: read -r line_num line; do
	ifacename=$(echo $line | grep -Eo "eth.")
	bond_line_number=$(echo "$line_num" | cut -d ":" -f1)
	
	#en $linea tenemos todo el contenido indentado detras de "iface eth"
	linea=$(awk -v n="$bond_line_number" 'NR > n && /^[[:space:]]/ {print; next} NR > n {exit}' $interfaces)
	addr=$(echo "$linea" | grep address | awk '{print $2}')
	
	#sustituimos el ultimo byte de $addr por un 1 
	via=$(echo "$addr" | awk -F '.' -v byte="1" '{$NF=byte} 1' OFS='.')

	echo -e "    $ifacename:"\
			"\n      dhcp4: no"\
			"\n      dhcp6: no"\
			"\n      addresses: [$addr/24]"\
			"\n      routes: "\
			"\n        - to: default"\
			"\n          via: $via" >> 01-network-manager-all.yaml		
done



#bond slaves
slaves=`grep slaves $interfaces | sed 's/slaves//g'`
for slave in $slaves; do
	echo -e "    $slave:"\
			"\n      dhcp4: no"\
			"\n      dhcp6: no" >> 01-network-manager-all.yaml	
done



#bonds
echo "  bonds:" >> 01-network-manager-all.yaml		
grep -n "iface bond" $interfaces | while IFS=: read -r line_num line; do
	ifacename=$(echo $line | grep -Eo "bond.")
	bond_line_number=$(echo "$line_num" | cut -d ":" -f1)
	
	linea=$(awk -v n="$bond_line_number" 'NR > n && /^[[:space:]]/ {print; next} NR > n {exit}' $interfaces)
	addr=$(echo "$linea" | grep address | awk '{print $2}')
	via=$(echo "$addr" | awk -F '.' -v byte="1" '{$NF=byte} 1' OFS='.')
	slave1=$(echo "$linea" | grep slaves | awk '{print $2}')
	slave2=$(echo "$linea" | grep slaves | awk '{print $3}')

	echo -e "    $ifacename:"\
			"\n      dhcp4: no"\
			"\n      dhcp6: no"\
			"\n      addresses: [$addr/24]"\
			"\n      nameservers:"\
			"\n        addresses: [8.8.8.8]"\
			"\n      routes: "\
			"\n        - to: default"\
			"\n          via: $via"\
			"\n      interfaces: [$slave1, $slave2]"\
			"\n      parameters:"\
			"\n        mode: active-backup"\
			"\n        mii-monitor-interval: 1"\
			"\n        fail-over-mac-policy: active"\
			"\n        primary: $slave1" >> 01-network-manager-all.yaml
done