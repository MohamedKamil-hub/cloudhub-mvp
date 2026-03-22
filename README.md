# Cloud-Hub MVP — SECCIÓN 9

Red corporativa segura para PYMES usando WireGuard, simulada con Containerlab.

## Qué es esto

Este proyecto simula una arquitectura de red real que podría vender una empresa de ciberseguridad a pequeñas empresas. La idea es sencilla: un servidor central en la nube (el "Hub") conecta a todos los empleados — estén en la oficina o en su casa — mediante túneles VPN cifrados con WireGuard.

En esta demo, todo corre en tu propio ordenador usando contenedores Docker orquestados por Containerlab. No necesitas servidores remotos ni hardware especial.

### Qué vas a ver funcionando

- Un **Hub central** (simula un VPS con OPNsense) que gestiona toda la red
- **3 empleados** conectados por VPN (2 en oficina, 1 teletrabajador)
- Un **servidor corporativo** accesible solo a través de la VPN
- **Split-tunneling**: el tráfico corporativo va por la VPN, internet sale directo
- **Firewall centralizado** con iptables en el Hub
- Todo controlado desde un solo fichero YAML

### Topología

```
                  ┌──────────────┐
                  │     HUB      │
                  │  WireGuard   │
                  │  10.10.1.1   │
                  └──────┬───────┘
                         │
            ┌────────────┼────────────┐
            │            │            │
     ┌──────┴──────┐ ┌───┴────┐ ┌────┴───────┐
     │  Spoke-OF1  │ │Spoke-OF2│ │ Spoke-REM1 │
     │  Oficina 1  │ │Oficina 2│ │Teletrabajo │
     │ 10.10.1.10  │ │10.10.1.11│ │ 10.10.1.20│
     └──────┬──────┘ └───┬────┘ └────┬───────┘
            │            │           │
        PC-OF1       PC-OF2     PC-REM1
     192.168.10.10  192.168.11.10  192.168.20.10

                  ┌──────────────┐
                  │  SRV-CORP    │
                  │  Servidor    │
                  │ 10.10.100.200│
                  └──────────────┘
```

---

## Requisitos

Necesitas una máquina Linux (Ubuntu 22.04 o superior). Puede ser una VM en VirtualBox.

| Software | Cómo instalarlo |
|---|---|
| **Docker** | `curl -fsSL https://get.docker.com \| sh` |
| **Containerlab** | `sudo bash -c "$(curl -sL https://get.containerlab.dev)"` |
| **WireGuard tools** | `sudo apt install -y wireguard-tools` |
| **Módulo WireGuard** | `sudo modprobe wireguard` (ya viene en kernels 5.6+) |

---

## Cómo ponerlo en marcha (5 pasos)

### Paso 1: Clonar el repo

```bash
git clone https://github.com/TU_USUARIO/cloudhub-mvp.git
cd cloudhub-mvp
```

### Paso 2: Construir las imágenes Docker (solo la primera vez)

Esto crea dos imágenes con los paquetes de red preinstalados. Tarda unos minutos la primera vez, después es instantáneo.

```bash
sudo docker build -t wg-node:latest -f Dockerfile.wg .
sudo docker build -t srv-node:latest -f Dockerfile.srv .
```

### Paso 3: Generar claves y configuraciones

Este script genera las claves WireGuard únicas para tu máquina y escribe todos los ficheros `.conf` automáticamente.

```bash
bash generate-configs.sh
```

### Paso 4: Desplegar el laboratorio

```bash
sudo containerlab deploy --topo cloudhub.clab.yml
```

Espera a que termine (debería tardar menos de 30 segundos). Verás una tabla con 8 nodos en estado `running`.

### Paso 5: Verificar que todo funciona

Espera 10 segundos tras el deploy y ejecuta los tests:

```bash
sleep 10
bash run-tests.sh
```

Deberías ver algo así:

```
  [PASS] Hub -> Spoke OF1 (10.10.1.10)
  [PASS] Hub -> Spoke OF2 (10.10.1.11)
  [PASS] Hub -> Spoke REM1 (10.10.1.20)
  [PASS] PC-OF1 -> Servidor (10.10.100.200)
  [PASS] PC-OF2 -> Servidor (10.10.100.200)
  [PASS] PC-REM1 -> Servidor (10.10.100.200)
  [PASS] PC-REM1 -> HTTP Servidor
  [PASS] PC-OF1 -> PC-REM1 (192.168.20.10)
  [PASS] PC-REM1 -> PC-OF1 (192.168.10.10)
  [PASS] Trafico VPN por wg0, internet por eth0

  RESULTADO: 10/10 PASS — MVP FUNCIONAL
```

---

## Pruebas manuales que puedes hacer

Una vez desplegado, puedes entrar en cualquier contenedor y hacer pruebas:

```bash
# Ver el estado de WireGuard en el Hub
sudo docker exec clab-cloudhub-hub wg show

# Desde el teletrabajador, acceder a la web del servidor corporativo
sudo docker exec clab-cloudhub-pc-rem1 wget -qO- http://10.10.100.200

# Ping entre un PC de oficina y el teletrabajador (pasa por el Hub)
sudo docker exec clab-cloudhub-pc-of1 ping -c 3 192.168.20.10

# Comprobar split-tunneling: ver por dónde va cada tipo de tráfico
sudo docker exec clab-cloudhub-spoke-rem1 ip route get 10.10.1.1      # -> wg0 (VPN)
sudo docker exec clab-cloudhub-spoke-rem1 ip route get 172.20.0.10    # -> eth0 (internet)
```

---

## Apagar y limpiar

```bash
# Apagar el laboratorio (elimina todos los contenedores)
sudo containerlab destroy --topo cloudhub.clab.yml

# Volver a desplegarlo cuando quieras
sudo containerlab deploy --topo cloudhub.clab.yml
```

---

## Estructura del proyecto

```
cloudhub-mvp/
├── cloudhub.clab.yml      # Topología de Containerlab (el "plano" de la red)
├── generate-configs.sh    # Genera claves WireGuard y escribe los .conf
├── run-tests.sh           # Tests automáticos de validación
├── Dockerfile.wg          # Imagen Docker con WireGuard preinstalado
├── Dockerfile.srv         # Imagen Docker para el servidor corporativo
├── hub/
│   ├── wg0.conf           # Config WireGuard del Hub (se genera con el script)
│   └── startup.sh         # Script de arranque del Hub
├── spoke-of1/             # Empleado oficina 1
│   ├── wg0.conf
│   └── startup.sh
├── spoke-of2/             # Empleado oficina 2
│   ├── wg0.conf
│   └── startup.sh
├── spoke-rem1/            # Teletrabajador
│   ├── wg0.conf
│   └── startup.sh
├── srv-corp/
│   └── startup.sh         # Servidor web corporativo
├── pc-of1/
│   └── startup.sh         # PC del empleado de oficina 1
├── pc-of2/
│   └── startup.sh         # PC del empleado de oficina 2
└── pc-rem1/
    └── startup.sh         # PC del teletrabajador
```

---

## Cómo funciona por dentro

1. **Containerlab** lee `cloudhub.clab.yml` y crea 8 contenedores Docker conectados entre sí.
2. El **Hub** y los **Spokes** establecen túneles WireGuard cifrados a través de la red de management (que simula internet).
3. Los **PCs** se conectan a sus respectivos Spokes por un enlace punto a punto (simula la red local del empleado).
4. El **servidor corporativo** está en una red privada conectada al Hub. Solo se puede acceder a él a través de la VPN.
5. El **split-tunneling** hace que solo el tráfico corporativo pase por la VPN. El tráfico a "internet" sale directo.

---

## Problemas comunes

| Problema | Solución |
|---|---|
| `containerlab: command not found` | Instalar Containerlab: `sudo bash -c "$(curl -sL https://get.containerlab.dev)"` |
| `wg: command not found` | Instalar WireGuard tools: `sudo apt install -y wireguard-tools` |
| `RTNETLINK: operation not supported` al levantar WireGuard | Cargar el módulo: `sudo modprobe wireguard` |
| Algún nodo en `restarting` | Destruir y redesplegar: `sudo containerlab destroy --topo cloudhub.clab.yml && sudo containerlab deploy --topo cloudhub.clab.yml` |
| Los `.conf` dicen `GENERATED_BY_SETUP_SCRIPT` | Ejecutar `bash generate-configs.sh` antes de desplegar |
| Imágenes Docker no encontradas | Construirlas: `sudo docker build -t wg-node:latest -f Dockerfile.wg .` |

---

## Autor

Proyecto desarrollado por **SECCIÓN 9** como MVP de servicio de ciberseguridad gestionada para PYMES.

Tecnologías: WireGuard, Docker, Containerlab, iptables, Linux.
