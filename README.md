# Cloud-Hub MVP — SECCIÓN 9

En esta demo, todo corre en tu propio ordenador usando contenedores Docker orquestados por Containerlab. No necesitas servidores remotos ni hardware especial.

### CONTIENE

- Un **Hub central** (simula un VPS con OPNsense) que gestiona toda la red
- **3 empleados** conectados por VPN (2 en oficina, 1 teletrabajador)
- Un **servidor corporativo** accesible solo a través de VPN
- **Split-tunneling**: el tráfico corporativo va por la VPN, internet sale directo
- **Firewall centralizado** con iptables en el Hub
- Todo controlado desde un solo YAML

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

- **Sistema operativo:** Ubuntu 22.04 o superior
- **RAM:** 4 GB mínimo
- **Disco:** 10 GB mínimo
- **Conexión a internet** (solo para la instalación inicial)

> **No necesitas instalar nada manualmente.** 
---

## 3 pasos

### Paso 1: Clonar el repo y ejecutar el setup

```bash
git clone https://github.com/MohamedKamil-hub/cloudhub-mvp
cd cloudhub-mvp
sudo bash setup.sh
newgrp docker
```

Este script instala automáticamente: Docker, WireGuard tools, Containerlab, construye las imágenes Docker y genera las claves WireGuard

> **al terminar el setup cierra sesión** `exit` para activar los permisos de Docker.

### Paso 2: Desplegar el laboratorio

```bash
sudo containerlab deploy --topo cloudhub.clab.yml
```

Cuando termine verás una tabla con 8 nodos en `running`.

### Paso 3: Verificar que todo funciona

```bash
sleep 10 && bash run-tests.sh
```

Deberías ver:

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

```bash
# Ver el estado de WireGuard en el Hub
sudo docker exec clab-cloudhub-hub wg show

# Desde el teletrabajador, acceder a la web del servidor corporativo
sudo docker exec clab-cloudhub-pc-rem1 wget -qO- http://10.10.100.200

# Ping entre un PC de oficina y el teletrabajador (pasa por el Hub)
sudo docker exec clab-cloudhub-pc-of1 ping -c 3 192.168.20.10

# Comprobar split-tunneling: ver por dónde va cada tipo de tráfico
sudo docker exec clab-cloudhub-spoke-rem1 ip route get 10.10.1.1      
sudo docker exec clab-cloudhub-spoke-rem1 ip route get 172.20.0.10    
```

---

## Apagar y limpiar

```bash
# Apagar el laboratorio 
sudo containerlab destroy --topo cloudhub.clab.yml

# Volver a desplegarlo cuando quieras
sudo containerlab deploy --topo cloudhub.clab.yml
```

---

## Estructura del proyecto

```
cloudhub-mvp/
├── cloudhub.clab.yml      # Topología de Containerlab (el "plano" de la red)
├── setup.sh               # Instala TODO y deja el entorno listo
├── generate-configs.sh    # Genera claves WireGuard y escribe los .conf
├── run-tests.sh           # Tests automáticos de validación
├── Dockerfile.wg          # Imagen Docker con WireGuard preinstalado
├── Dockerfile.srv         # Imagen Docker para el servidor corporativo
├── hub/
│   ├── wg0.conf           # Config WireGuard del Hub (se genera automáticamente)
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

## Cómo funciona

1. **Containerlab** lee `cloudhub.clab.yml` y crea 8 contenedores Docker conectados entre sí.
2. El **Hub** y los **Spokes** establecen túneles WireGuard cifrados a través de la red de management que simula internet
3. Los **PCs** se conectan a sus respectivos Spokes por un enlace punto a punto q simula la red local del empleado.
4. El **servidor corporativo** está en una red privada conectada al Hub. Solo se puede acceder a él a través de la VPN.
5. El **split-tunneling** hace que solo el tráfico corporativo pase por la VPN. El tráfico a "internet" sale directo.


