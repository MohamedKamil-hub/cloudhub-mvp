#!/bin/bash
# ============================================================
# setup.sh — Cloud-Hub MVP — SECCIÓN 9
# Preparación completa del entorno (ejecutar UNA SOLA VEZ)
# ============================================================
#
# Uso:  sudo bash setup.sh
#
# Este script instala todas las dependencias necesarias,
# construye las imágenes Docker y deja el entorno listo
# para desplegar el laboratorio con un solo comando.
# ============================================================

set -e 

# ── Colores para output legible ──
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' 

ok()   { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[!]${NC} $1"; }
fail() { echo -e "  ${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "\n${YELLOW}▸ $1${NC}"; }

# ── Verificar que se ejecuta como root ──
if [ "$EUID" -ne 0 ]; then
    fail "Ejecuta este script con sudo: sudo bash setup.sh"
fi

# Detectar el usuario no root para añadirlo a grupos
REAL_USER="${SUDO_USER:-$USER}"

echo ""
echo "========================================="
echo " SETUP — Cloud-Hub MVP — SECCIÓN 9"
echo "========================================="
echo " Usuario detectado: $REAL_USER"
echo "========================================="

# ── 1. Actualizar repositorios ──
step "1/7 — Actualizando repositorios..."
apt-get update -qq
ok "Repositorios actualizados"

# ── 2. Instalar dependencias del sistema ──
step "2/7 — Instalando dependencias (Docker, WireGuard, tree)..."

# Docker
if command -v docker &>/dev/null; then
    ok "Docker ya instalado ($(docker --version | cut -d' ' -f3 | tr -d ','))"
else
    apt-get install -y -qq docker.io
    ok "Docker instalado"
fi

# WireGuard tools (necesario en el HOST para generar claves)
if command -v wg &>/dev/null; then
    ok "WireGuard tools ya instalado"
else
    apt-get install -y -qq wireguard-tools
    ok "WireGuard tools instalado"
fi

# Tree (opcional, para visualizar la estructura)
if command -v tree &>/dev/null; then
    ok "tree ya instalado"
else
    apt-get install -y -qq tree
    ok "tree instalado"
fi

# ── 3. Cargar módulo WireGuard en el kernel ──
step "3/7 — Cargando módulo WireGuard en el kernel..."
if lsmod | grep -q wireguard; then
    ok "Módulo wireguard ya cargado"
else
    modprobe wireguard 2>/dev/null && ok "Módulo wireguard cargado" || warn "No se pudo cargar el módulo wireguard. En kernels 5.6+ suele estar integrado, debería funcionar igualmente."
fi

# ── 4. Configurar grupo Docker (para evitar 'permission denied') ──
step "4/7 — Configurando permisos Docker para '$REAL_USER'..."
if groups "$REAL_USER" | grep -q docker; then
    ok "$REAL_USER ya está en el grupo docker"
else
    usermod -aG docker "$REAL_USER"
    ok "$REAL_USER añadido al grupo docker"
    warn "IMPORTANTE: Tras el setup, ejecuta 'newgrp docker' o cierra sesión y vuelve a entrar para que el cambio surta efecto."
fi

# Asegurar que el servicio Docker está activo
systemctl is-active --quiet docker || systemctl start docker
systemctl is-enabled --quiet docker || systemctl enable docker
ok "Servicio Docker activo y habilitado"

# ── 5. Instalar Containerlab ──
step "5/7 — Instalando Containerlab..."
if command -v containerlab &>/dev/null; then
    ok "Containerlab ya instalado ($(containerlab version 2>/dev/null | head -1 | awk '{print $2}' || echo 'versión desconocida'))"
else
    bash -c "$(curl -sL https://get.containerlab.dev)" 2>/dev/null
    if command -v containerlab &>/dev/null; then
        ok "Containerlab instalado"
    else
        fail "No se pudo instalar Containerlab. Verifica tu conexión a internet."
    fi
fi

# ── 6. Construir imágenes Docker ──
step "6/7 — Construyendo imágenes Docker..."

# Verificar que los Dockerfiles existen
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SCRIPT_DIR/Dockerfile.wg" ]; then
    fail "No se encuentra Dockerfile.wg. Ejecuta este script desde el directorio del proyecto."
fi

if [ ! -f "$SCRIPT_DIR/Dockerfile.srv" ]; then
    fail "No se encuentra Dockerfile.srv. Ejecuta este script desde el directorio del proyecto."
fi

echo "  Construyendo wg-node (WireGuard + iptables)..."
docker build -q -t wg-node:latest -f "$SCRIPT_DIR/Dockerfile.wg" "$SCRIPT_DIR" && ok "Imagen wg-node:latest construida" || fail "Error construyendo wg-node"

echo "  Construyendo srv-node (servidor corporativo)..."
docker build -q -t srv-node:latest -f "$SCRIPT_DIR/Dockerfile.srv" "$SCRIPT_DIR" && ok "Imagen srv-node:latest construida" || fail "Error construyendo srv-node"

# ── 7. Generar claves y configuraciones WireGuard ──
step "7/7 — Generando claves WireGuard y configuraciones..."

if [ ! -f "$SCRIPT_DIR/generate-configs.sh" ]; then
    fail "No se encuentra generate-configs.sh."
fi

bash "$SCRIPT_DIR/generate-configs.sh"
ok "Claves y configuraciones generadas"

# ── Resumen final ──
echo ""
echo "========================================="
echo -e " ${GREEN}SETUP COMPLETADO${NC}"
echo "========================================="
echo ""
echo " Todo listo. Para desplegar el laboratorio:"
echo ""
echo "   sudo containerlab deploy --topo cloudhub.clab.yml"
echo ""
echo " Espera 10 segundos y ejecuta los tests:"
echo ""
echo "   sleep 10 && bash run-tests.sh"
echo ""
if ! groups "$REAL_USER" | grep -q docker; then
    echo -e " ${YELLOW}RECUERDA: Cierra sesión y vuelve a entrar"
    echo -e " (o ejecuta 'newgrp docker') para que los"
    echo -e " permisos de Docker surtan efecto.${NC}"
    echo ""
fi
echo "========================================="
