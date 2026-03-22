#!/bin/ash
for i in $(seq 1 30); do ip link show eth1 >/dev/null 2>&1 && break; sleep 1; done
ip addr add 192.168.10.10/24 dev eth1 2>/dev/null || true
ip link set eth1 up
ip route add 10.10.1.0/24 via 192.168.10.1 || true
ip route add 10.10.100.0/24 via 192.168.10.1 || true
ip route add 192.168.11.0/24 via 192.168.10.1 || true
ip route add 192.168.20.0/24 via 192.168.10.1 || true
echo "[PC-OF1] listo"
tail -f /dev/null
