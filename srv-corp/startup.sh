#!/bin/bash
for i in $(seq 1 30); do ip link show eth1 >/dev/null 2>&1 && break; sleep 1; done
ip addr add 10.10.100.200/24 dev eth1
ip link set eth1 up
# Rutas hacia las LANs de los spokes via el Hub
ip route add 10.10.1.0/24 via 10.10.100.1 || true
ip route add 192.168.10.0/24 via 10.10.100.1 || true
ip route add 192.168.11.0/24 via 10.10.100.1 || true
ip route add 192.168.20.0/24 via 10.10.100.1 || true

echo "<h1>Servidor Corporativo SECCION 9</h1><p>Acceso solo via VPN - 10.10.100.200</p>" > /tmp/index.html
cd /tmp && python3 -m http.server 80 &
echo "[SRV-CORP] activo"
tail -f /dev/null
