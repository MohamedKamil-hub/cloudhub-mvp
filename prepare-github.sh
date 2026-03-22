#!/bin/bash
# ============================================================
# SCRIPT DE PREPARACIÓN PARA GITHUB — Cloud-Hub MVP SECCIÓN 9
# Ejecutar desde ~/cloudhub-mvp
# ============================================================
set -e
cd ~/cloudhub-mvp

echo "========================================="
echo " Limpiando repo para subir a GitHub"
echo "========================================="

# 1. Eliminar claves privadas y públicas (NUNCA se suben a GitHub)
echo "[1/6] Eliminando claves privadas y públicas..."
rm -f hub/privatekey hub/publickey
rm -f spoke-of1/privatekey spoke-of1/publickey
rm -f spoke-of2/privatekey spoke-of2/publickey
rm -f spoke-rem1/privatekey spoke-rem1/publickey

# 2. Eliminar directorio temporal de containerlab
echo "[2/6] Eliminando ficheros temporales de containerlab..."
rm -rf clab-cloudhub/

# 3. Poner placeholders seguros en los .conf (por si alguien olvidó limpiarlos)
echo "[3/6] Limpiando claves de los .conf (poniendo placeholders)..."

cat > hub/wg0.conf << 'EOF'
[Interface]
PrivateKey = GENERATED_BY_SETUP_SCRIPT
Address = 10.10.1.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -A FORWARD -i eth1 -j ACCEPT; iptables -A FORWARD -o eth1 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -D FORWARD -i eth1 -j ACCEPT; iptables -D FORWARD -o eth1 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = GENERATED_BY_SETUP_SCRIPT
AllowedIPs = 10.10.1.10/32, 192.168.10.0/24

[Peer]
PublicKey = GENERATED_BY_SETUP_SCRIPT
AllowedIPs = 10.10.1.11/32, 192.168.11.0/24

[Peer]
PublicKey = GENERATED_BY_SETUP_SCRIPT
AllowedIPs = 10.10.1.20/32, 192.168.20.0/24
EOF

cat > spoke-of1/wg0.conf << 'EOF'
[Interface]
PrivateKey = GENERATED_BY_SETUP_SCRIPT
Address = 10.10.1.10/32

[Peer]
PublicKey = GENERATED_BY_SETUP_SCRIPT
Endpoint = 172.20.0.10:51820
AllowedIPs = 10.10.1.0/24, 10.10.100.0/24, 192.168.11.0/24, 192.168.20.0/24
PersistentKeepalive = 25
EOF

cat > spoke-of2/wg0.conf << 'EOF'
[Interface]
PrivateKey = GENERATED_BY_SETUP_SCRIPT
Address = 10.10.1.11/32

[Peer]
PublicKey = GENERATED_BY_SETUP_SCRIPT
Endpoint = 172.20.0.10:51820
AllowedIPs = 10.10.1.0/24, 10.10.100.0/24, 192.168.10.0/24, 192.168.20.0/24
PersistentKeepalive = 25
EOF

cat > spoke-rem1/wg0.conf << 'EOF'
[Interface]
PrivateKey = GENERATED_BY_SETUP_SCRIPT
Address = 10.10.1.20/32

[Peer]
PublicKey = GENERATED_BY_SETUP_SCRIPT
Endpoint = 172.20.0.10:51820
AllowedIPs = 10.10.1.0/24, 10.10.100.0/24, 192.168.10.0/24, 192.168.11.0/24
PersistentKeepalive = 25
EOF

# 4. Crear .gitignore
echo "[4/6] Creando .gitignore..."
cat > .gitignore << 'EOF'
# Claves WireGuard (NUNCA subir a GitHub)
*/privatekey
*/publickey

# Ficheros temporales de Containerlab
clab-cloudhub/

# Ficheros del sistema
*.swp
*.swo
*~
.DS_Store
EOF

# 5. Crear generate-configs.sh
echo "[5/6] Creando generate-configs.sh..."
cat > generate-configs.sh << 'GENSCRIPT'
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
GENSCRIPT
chmod +x generate-configs.sh

# 6. Crear run-tests.sh
echo "[6/6] Creando run-tests.sh..."
cat > run-tests.sh << 'TESTSCRIPT'
#!/bin/bash
# ==============================================
# Tests de validacion del MVP Cloud-Hub
# Ejecutar despues de: sudo containerlab deploy
# ==============================================

echo ""
echo "========================================="
echo " TESTS MVP CLOUD-HUB — SECCION 9"
echo "========================================="
echo ""

PASS=0; FAIL=0

run_test() {
    local desc="$1"; shift
    if eval "$@" >/dev/null 2>&1; then
        echo "  [PASS] $desc"; ((PASS++))
    else
        echo "  [FAIL] $desc"; ((FAIL++))
    fi
}

echo "--- Estado de nodos ---"
docker ps --filter "name=clab-cloudhub" --format "  {{.Names}}: {{.Status}}" | sort

echo ""
echo "--- WireGuard Hub ---"
sudo docker exec clab-cloudhub-hub wg show | grep -E "peer|endpoint|handshake" | sed 's/^/  /'

echo ""
echo "--- Conectividad VPN (Hub -> Spokes) ---"
run_test "Hub -> Spoke OF1 (10.10.1.10)" "sudo docker exec clab-cloudhub-hub ping -c 1 -W 3 10.10.1.10"
run_test "Hub -> Spoke OF2 (10.10.1.11)" "sudo docker exec clab-cloudhub-hub ping -c 1 -W 3 10.10.1.11"
run_test "Hub -> Spoke REM1 (10.10.1.20)" "sudo docker exec clab-cloudhub-hub ping -c 1 -W 3 10.10.1.20"

echo ""
echo "--- Acceso al servidor corporativo ---"
run_test "PC-OF1 -> Servidor (10.10.100.200)" "sudo docker exec clab-cloudhub-pc-of1 ping -c 1 -W 3 10.10.100.200"
run_test "PC-OF2 -> Servidor (10.10.100.200)" "sudo docker exec clab-cloudhub-pc-of2 ping -c 1 -W 3 10.10.100.200"
run_test "PC-REM1 -> Servidor (10.10.100.200)" "sudo docker exec clab-cloudhub-pc-rem1 ping -c 1 -W 3 10.10.100.200"
run_test "PC-REM1 -> HTTP Servidor" "sudo docker exec clab-cloudhub-pc-rem1 wget -qO- --timeout=3 http://10.10.100.200"

echo ""
echo "--- Comunicacion entre spokes (via Hub) ---"
run_test "PC-OF1 -> PC-REM1 (192.168.20.10)" "sudo docker exec clab-cloudhub-pc-of1 ping -c 1 -W 3 192.168.20.10"
run_test "PC-REM1 -> PC-OF1 (192.168.10.10)" "sudo docker exec clab-cloudhub-pc-rem1 ping -c 1 -W 3 192.168.10.10"

echo ""
echo "--- Split-tunneling ---"
VPN_OK=$(sudo docker exec clab-cloudhub-spoke-rem1 ip route get 10.10.1.1 2>/dev/null | grep -c wg0)
NET_OK=$(sudo docker exec clab-cloudhub-spoke-rem1 ip route get 172.20.0.10 2>/dev/null | grep -c eth0)
if [ "$VPN_OK" -ge 1 ] && [ "$NET_OK" -ge 1 ]; then
    echo "  [PASS] Trafico VPN por wg0, internet por eth0"; ((PASS++))
else
    echo "  [FAIL] Split-tunneling no verificado"; ((FAIL++))
fi

echo ""
echo "========================================="
if [ "$FAIL" -eq 0 ]; then
    echo " RESULTADO: ${PASS}/${PASS} PASS — MVP FUNCIONAL"
else
    echo " RESULTADO: ${PASS} passed, ${FAIL} failed"
fi
echo "========================================="
echo ""
TESTSCRIPT
chmod +x run-tests.sh

echo ""
echo "========================================="
echo " Limpieza completada."
echo "========================================="
echo ""
echo "Verifica que no hay claves privadas:"
echo "---"
find . -name "privatekey" -o -name "publickey" | head -20
echo "---"
echo ""
echo "Estructura final:"
find . -not -path './clab-cloudhub/*' -not -path './.git/*' -not -name 'privatekey' -not -name 'publickey' | sort
echo ""
echo "Ahora puedes hacer:"
echo "  cd ~/cloudhub-mvp"
echo "  git init"
echo "  git add ."
echo "  git commit -m 'MVP Cloud-Hub SECCION 9'"
echo "  git remote add origin https://github.com/TU_USUARIO/cloudhub-mvp.git"
echo "  git push -u origin main"
