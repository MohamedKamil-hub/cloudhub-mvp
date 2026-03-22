#!/bin/bash
# =================================================================
# Genera claves WireGuard y escribe los .conf con las claves reales
# Ejecutar una sola vez antes del primer deploy
# =================================================================
set -e
cd "$(dirname "$0")"

echo "Generando claves WireGuard..."
for node in hub spoke-of1 spoke-of2 spoke-rem1; do
    wg genkey | tee $node/privatekey | wg pubkey > $node/publickey
done

HUB_PRIV=$(cat hub/privatekey)
HUB_PUB=$(cat hub/publickey)
OF1_PRIV=$(cat spoke-of1/privatekey)
OF1_PUB=$(cat spoke-of1/publickey)
OF2_PRIV=$(cat spoke-of2/privatekey)
OF2_PUB=$(cat spoke-of2/publickey)
REM1_PRIV=$(cat spoke-rem1/privatekey)
REM1_PUB=$(cat spoke-rem1/publickey)

cat > hub/wg0.conf << EOF
[Interface]
PrivateKey = ${HUB_PRIV}
Address = 10.10.1.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -A FORWARD -i eth1 -j ACCEPT; iptables -A FORWARD -o eth1 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -D FORWARD -i eth1 -j ACCEPT; iptables -D FORWARD -o eth1 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = ${OF1_PUB}
AllowedIPs = 10.10.1.10/32, 192.168.10.0/24

[Peer]
PublicKey = ${OF2_PUB}
AllowedIPs = 10.10.1.11/32, 192.168.11.0/24

[Peer]
PublicKey = ${REM1_PUB}
AllowedIPs = 10.10.1.20/32, 192.168.20.0/24
EOF

cat > spoke-of1/wg0.conf << EOF
[Interface]
PrivateKey = ${OF1_PRIV}
Address = 10.10.1.10/32

[Peer]
PublicKey = ${HUB_PUB}
Endpoint = 172.20.0.10:51820
AllowedIPs = 10.10.1.0/24, 10.10.100.0/24, 192.168.11.0/24, 192.168.20.0/24
PersistentKeepalive = 25
EOF

cat > spoke-of2/wg0.conf << EOF
[Interface]
PrivateKey = ${OF2_PRIV}
Address = 10.10.1.11/32

[Peer]
PublicKey = ${HUB_PUB}
Endpoint = 172.20.0.10:51820
AllowedIPs = 10.10.1.0/24, 10.10.100.0/24, 192.168.10.0/24, 192.168.20.0/24
PersistentKeepalive = 25
EOF

cat > spoke-rem1/wg0.conf << EOF
[Interface]
PrivateKey = ${REM1_PRIV}
Address = 10.10.1.20/32

[Peer]
PublicKey = ${HUB_PUB}
Endpoint = 172.20.0.10:51820
AllowedIPs = 10.10.1.0/24, 10.10.100.0/24, 192.168.10.0/24, 192.168.11.0/24
PersistentKeepalive = 25
EOF

chmod 600 hub/wg0.conf spoke-*/wg0.conf
echo ""
echo "Claves generadas y configs escritos correctamente."
echo "Las claves privadas estan en */privatekey — NO las subas a GitHub."
