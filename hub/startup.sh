#!/bin/bash
sysctl -w net.ipv4.ip_forward=1
for i in $(seq 1 30); do ip link show eth1 >/dev/null 2>&1 && break; sleep 1; done
ip addr add 10.10.100.1/24 dev eth1 2>/dev/null || true
ip link set eth1 up 2>/dev/null || true
wg-quick up /etc/wireguard/wg0.conf || { sleep 3; wg-quick up /etc/wireguard/wg0.conf; }
# Ruta para que el tráfico al servidor pase por eth1
ip route add 10.10.100.0/24 dev eth1 2>/dev/null || true
echo "[HUB] activo"
wg show
tail -f /dev/null
