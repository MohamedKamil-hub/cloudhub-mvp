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
