## 1. Resumen 

Esta propuesta define una arquitectura de red segura, centralizada y gestionada 100% en remoto para PYMES. El modelo no requiere instalar ningún hardware en las instalaciones del cliente: ni routers, ni mini-PCs, ni appliances de firewall. Toda la política de seguridad se concentra en un servidor virtual (VPS) en la nube que ejecuta OPNsense.

Cada dispositivo del cliente — ya sea un PC en la oficina o un portátil de un teletrabajador — instala un cliente WireGuard ligero y se conecta directamente al VPS. No hay diferencia técnica entre "estar en la oficina" y "estar en casa": todos los equipos son spokes iguales conectados al mismo Hub centralizado.

El resultado es una red corporativa completa — con VPN, firewall, segmentación y monitorización — que SECCIÓN 9 puede desplegar, mantener y facturar como servicio recurrente. El único requisito para el cliente es instalar una aplicación en cada equipo.

---

## 2. Arquitectura Técnica

### 2.1 Topología: Hub-and-Spoke -- Software

El diseño sigue una topología **Hub-and-Spoke basada en software**, equivalente a una SD-WAN simplificada. La diferencia clave de esta propuesta es que **no existe hardware dedicado en ningún spoke**: cada dispositivo del cliente es un spoke individual.

|Componente|Rol|Detalle|
|---|---|---|
|**Hub** (VPS en Hetzner)|Gateway central|OPNsense con IP pública fija. Termina todos los túneles VPN. Aplica reglas de firewall, filtrado y segmentación.|
|**Spokes** (Todos los equipos)|Dispositivos conectados|Cada PC, portátil o móvil del cliente ejecuta el cliente WireGuard. Establece un túnel individual hacia el Hub. No importa si está en la oficina, en casa o en una cafetería.|

**Direccionamiento interno:** Red `10.10.1.0/24`, asignada por OPNsense. Cada dispositivo recibe una IP fija dentro de este rango (ej. `10.10.1.10`, `10.10.1.11`, etc.). Todos los nodos se ven entre sí a través del Hub, independientemente de su ISP o ubicación física.

**Ventaja fundamental del modelo 100% VPS:** No hay que visitar la oficina del cliente para instalar nada. Todo se despliega en remoto: se configura el VPS, se generan los perfiles WireGuard, y se envían al cliente por canal seguro. El cliente solo tiene que instalar la app de WireGuard e importar su perfil.

### 2.2 Protocolo VPN: WireGuard

Se elige WireGuard sobre OpenVPN por las siguientes razones prácticas:

- **Rendimiento:** Overhead criptográfico mínimo. La latencia añadida entre Madrid y un datacenter en Alemania (Hetzner Falkenstein/Nuremberg) se mantiene en torno a 25–35 ms, aceptable para cualquier aplicación corporativa.
- **Simplicidad de despliegue:** Cada peer se define con un par de claves y una IP. No hay certificados complejos ni infraestructura PKI. El cliente recibe un fichero `.conf` o un código QR y en dos minutos está conectado.
- **Estabilidad:** Reconexión automática y silenciosa ante cambios de red (por ejemplo, un portátil que pasa de WiFi a datos móviles).
- **Multiplataforma:** Clientes disponibles para Windows, macOS, Linux, iOS y Android. Sin coste de licencia.

**Limitación conocida:** WireGuard no soporta autenticación de usuario nativa (no hay capa de login con usuario/contraseña). La seguridad se basa en la custodia de las claves privadas. Esto se mitiga con: distribución segura de los perfiles, 2FA obligatorio en el panel de gestión de OPNsense, y la posibilidad de revocar un peer instantáneamente desde el Hub si un dispositivo se compromete.

### 2.3 Cómo se Conecta la Oficina 

En el modelo 100% VPS, la oficina del cliente no necesita ningún equipamiento especial. Cada PC de la oficina instala su propio cliente WireGuard, igual que lo haría un teletrabajador. La conexión es individual por dispositivo.

**Flujo en la oficina:**

1. El PC de la oficina arranca y el servicio WireGuard se inicia automáticamente (se configura como servicio del sistema).
2. Se establece un túnel cifrado hacia la IP pública del VPS.
3. El PC recibe su IP interna (`10.10.1.x`) y ya puede ver al resto de equipos de la red corporativa.
4. El router del ISP del cliente (Jazztel, Movistar, etc.) no se toca. Solo proporciona internet. No necesita configuración especial ni modo puente.

**¿Y si los PCs de la oficina necesitan verse entre sí localmente?** A través del Hub. El tráfico entre dos PCs de la misma oficina viaja: PC-A → túnel WireGuard → Hub (VPS) → túnel WireGuard → PC-B. Esto añade una latencia mínima (~50–70 ms ida y vuelta a Alemania) que es imperceptible para carpetas compartidas, impresoras de red o aplicaciones internas. Para tráfico pesado entre equipos locales (ej. transferencias masivas de ficheros), el split-tunneling se puede ajustar para que el tráfico LAN no pase por la VPN.

### 2.4 Segmentación y Control de Acceso

Desde OPNsense en el Hub se pueden crear reglas granulares por IP de peer. Ejemplos:

- El equipo del gerente (`10.10.1.10`) puede acceder a todos los recursos.
- Los equipos de los empleados (`10.10.1.20–40`) solo pueden acceder al servidor de ficheros (`10.10.1.100`) pero no entre sí.
- Un dispositivo BYOD (`10.10.1.50`) tiene acceso restringido solo a la aplicación web interna.

Todo esto se gestiona desde el panel de OPNsense sin tocar los equipos del cliente.

---

## 3. Infraestructura: VPS en Hetzner

### 3.1 ¿Por qué un VPS dedicado no administrado?

Un VPS no administrado ofrece control total sobre el sistema operativo y la configuración de red. No hay panel de hosting ni limitaciones de software. Se instala OPNsense directamente desde ISO — Hetzner permite esto a través de su consola KVM remota, que se solicita por ticket y es gratuita por horas.

Además, Hetzner dispone de **vKVM**, una consola de rescate que permite arrancar el sistema instalado en disco dentro de una máquina virtual temporal. Esto es la red de seguridad: si una mala regla de firewall bloquea el acceso remoto, se puede corregir desde vKVM sin acceso físico.

### 3.2 ¿Por qué Hetzner?

|Criterio|Valoración|
|---|---|
|**Rendimiento**|Procesadores AMD EPYC, NVMe de última generación. Supera consistentemente a la flota mixta de otros proveedores como OVH.|
|**Instalación de ISO propio**|Soportado vía consola KVM remota. Imprescindible para instalar OPNsense.|
|**Consola de rescate (vKVM)**|Permite corregir errores de configuración que bloqueen el acceso remoto.|
|**Latencia desde España**|Datacenters en Alemania (~25–35 ms desde Madrid). Aceptable para WireGuard.|
|**Interfaz y API**|Limpia, minimalista y bien documentada. Relevante para gestión remota eficiente.|
|**Precio**|CX22 (2 vCPU, 4 GB RAM, 40 GB NVMe): **~4,50 €/mes**. Suficiente para OPNsense con WireGuard y 10–20 usuarios.|

### 3.3 Inversión Inicial de SECCIÓN 9 (< 200 €)

Este presupuesto cubre lo que SECCIÓN 9 necesita para tener el servicio operativo y listo para vender al primer cliente.

| Concepto                                           | Coste                | Tipo               |
| -------------------------------------------------- | -------------------- | ------------------ |
| VPS Hetzner CX22 (primer mes + setup)              | ~4,50 €              | Recurrente mensual |
| Dominio de gestión (ej. `hub.seccion9.es`)         | ~10 €/año            | Recurrente anual   |
| Tiempo de formación y laboratorio                  | 0 €                  | Único              |
| Herramientas de trabajo (ya disponibles)           | 0 €                  | —                  |
| VPS de pruebas/laboratorio (opcional, recomendado) | ~4,50 €/mes          | Recurrente mensual |
| **Total inversión real para arrancar**             | **20 € para 1º mes** | —                  |
| **Reserva recomendada (6 meses de infra)**         | **~60 €**            | —                  |

> **Nota:** El presupuesto de 200 € es más que suficiente. Con menos de 20 € se puede tener el primer Hub operativo. Los 200 € permiten mantener la infraestructura de laboratorio + producción durante meses antes de que entre el primer cliente. 

### 3.4 ¿Qué Paga el Cliente?

El cliente no compra hardware ni VPS. Paga a SECCIÓN 9 una cuota de servicio gestionado. SECCIÓN 9 decide si incluye el coste del VPS en la cuota o si lo factura aparte.

|Lo que recibe el cliente|Cómo se entrega|
|---|---|
|Red corporativa segura con VPN|Configuración en el VPS de SECCIÓN 9|
|Firewall centralizado|Reglas gestionadas por SECCIÓN 9|
|Perfiles WireGuard para cada empleado|Fichero `.conf` o código QR enviado por canal seguro|
|Soporte y mantenimiento|Remoto, incluido en la cuota mensual|

**No necesita:** Ni hardware, ni conocimientos técnicos, ni acceso al VPS. Solo instalar WireGuard en sus equipos.

---

## 4. Seguridad

### 4.1 Autenticación de Doble Factor (2FA)

OPNsense soporta TOTP (RFC 6238) de forma nativa. El flujo de autenticación es:

1. El administrador (SECCIÓN 9) introduce su contraseña.
2. Introduce el código de 6 dígitos generado por su app de autenticación (Google Authenticator, Aegis, etc.).
3. OPNsense valida ambos factores antes de conceder acceso al panel de gestión.

**Alcance del 2FA:**

- **Panel web de OPNsense:** Se aplica al login de administración. Obligatorio para SECCIÓN 9.
- **VPN WireGuard:** No tiene capa de autenticación propia (funciona por claves criptográficas). La seguridad del túnel recae en la custodia de las claves privadas. Si un dispositivo se pierde o se compromete, SECCIÓN 9 revoca ese peer desde el Hub en segundos.

Documentación: [OPNsense — Two Factor Authentication](https://docs.opnsense.org/manual/two_factor.html)

### 4.2 Gestión Remota del Firewall

OPNsense se administra al 100% por interfaz web (HTTPS) o SSH. No es necesario acceso físico al servidor. Este es el modelo operativo que permite a SECCIÓN 9 gestionar la infraestructura de múltiples clientes desde una ubicación centralizada.

**Riesgo principal:** Si se aplica una regla de firewall errónea, se puede perder el acceso remoto al VPS.

**Mitigaciones obligatorias:**

1. Configurar siempre una regla `allow SSH desde IP de gestión de SECCIÓN 9` como primera regla, antes de cualquier cambio.
2. Usar la consola VNC/vKVM del proveedor (Hetzner) como acceso de emergencia.
3. Mantener backups actualizados de la configuración (ver sección 6).

### 4.3 WAF (Web Application Firewall) — Complemento Opcional

Un WAF es un sistema que filtra tráfico HTTP/HTTPS y protege aplicaciones web contra ataques de capa 7 (modelo OSI): inyección SQL, XSS, CSRF, inclusión de archivos, fuerza bruta y bots.

**Importante: Un WAF y OPNsense no hacen lo mismo ni son intercambiables.**

|Aspecto|OPNsense (Firewall/VPN)|WAF|
|---|---|---|
|**Capa OSI**|Capas 3 y 4 (IPs, puertos)|Capa 7 (contenido web, URLs, formularios)|
|**Función principal**|Conectar sedes y teletrabajadores. Segmentar la red.|Proteger una aplicación web expuesta a internet.|
|**Acceso remoto**|Sí, mediante túneles VPN.|No. No crea túneles ni conecta usuarios a la red interna.|
|**Protección**|Bloquea IPs, controla puertos, filtra tráfico de red.|Bloquea ataques al código de la aplicación web.|

**¿Cuándo ofrecer WAF al cliente?** Solo si el cliente tiene una aplicación web expuesta a internet (web corporativa, portal de clientes, e-commerce). En ese caso, se recomienda Cloudflare como WAF en la nube por su facilidad de implementación y su capa gratuita que ya incluye protección básica DDoS y reglas WAF.

**El WAF no sustituye a OPNsense.** Un WAF no crea VPN, no segmenta red, no controla puertos internos, y no protege servicios no-web (impresoras, RDP, bases de datos, carpetas compartidas).

**Modelo recomendado:** OPNsense como base obligatoria + WAF como complemento si existen servicios web públicos.

---

## 5. Diseño de Resiliencia

### 5.1 Punto Único de Fallo y Mitigaciones

El principal riesgo de esta arquitectura es que si el VPS cae, la red corporativa se interrumpe. Estas son las estrategias para mitigarlo, ordenadas de menor a mayor complejidad:

#### Split-Tunneling (Configuración base)

En lugar de enviar todo el tráfico por la VPN (full tunnel), se configura el cliente WireGuard para que solo el tráfico dirigido a la red interna (`10.10.1.0/24`) viaje por el túnel. El tráfico a internet (navegación, correo, videollamadas) sale directamente por la conexión local del empleado.

**Resultado:** Si el VPS cae, el empleado pierde acceso a recursos internos (carpetas, servidores) pero conserva internet. La productividad básica no se detiene.

 [OPNsense — WireGuard Selective Routing](https://docs.opnsense.org/manual/how-tos/wireguard-selective-routing.html)

**En la práctica, el fichero `.conf` de WireGuard del cliente se configura así:**

```ini
[Interface]
PrivateKey = <clave_privada_del_empleado>
Address = 10.10.1.20/32

[Peer]
PublicKey = <clave_publica_del_hub>
Endpoint = 85.45.69.8:51820
AllowedIPs = 10.10.1.0/24
PersistentKeepalive = 25
```

La línea `AllowedIPs = 10.10.1.0/24` es la que define el split-tunneling: solo el tráfico dirigido a esa red viaja por la VPN. Todo lo demás sale por la conexión normal del empleado.

Si se quiere full tunnel (todo el tráfico por la VPN), se cambia a `AllowedIPs = 0.0.0.0/0`.

#### Kill Switch Opcional

En el cliente WireGuard de cada equipo:

- **Kill Switch ON:** Si la VPN cae, se corta todo el internet. Máxima seguridad, mínima disponibilidad.
- **Kill Switch OFF:** Si la VPN cae, el equipo sigue navegando normalmente. Solo pierde acceso a la red corporativa.

**Recomendación para PYMES:** Kill Switch OFF combinado con split-tunneling. Priorizar continuidad operativa.

#### VPS de Respaldo (Para quienes lo requieran)

Para clientes que necesiten alta disponibilidad, se despliega un segundo VPS con una copia de la configuración. Un script automatizado detecta si el VPS principal ha caído y redirige el tráfico al secundario.

**Coste adicional para SECCIÓN 9:** ~4,50 €/mes (segundo CX22). Se ofrece como upgrade del servicio y se factura al cliente con margen.

### 5.2 Ancho de Banda y Escalado

Si el cliente tiene más de 20–30 empleados simultáneos con tráfico pesado, la CPU y el ancho de banda del VPS CX22 pueden quedarse cortos. En ese caso, se escala al CX32 (4 vCPU, 8 GB RAM) o superior. La migración es sencilla: snapshot + restauración en una instancia mayor.

---

## 6. Backups

### 6.1 Backup Manual

OPNsense permite exportar la configuración completa desde `System → Configuration → Backups`. El fichero resultante es un XML que contiene todas las reglas, interfaces, usuarios y túneles. Se puede proteger con contraseña.

### 6.2 Backup Automatizado 

OPNsense expone una API que permite descargar la configuración sin intervención manual. El flujo recomendado:

1. Crear un usuario en OPNsense con privilegios mínimos (solo `Diagnostics: Configuration History`).
2. Generar una clave API + secreto para ese usuario.
3. Configurar un cron job (en un servidor de gestión de SECCIÓN 9 o en el propio VPS) que cada noche ejecute un `curl` autenticado a la API de OPNsense, descargue el `config.xml` y lo almacene en un repositorio Git privado o un Nextcloud.

OPNsense también soporta backup integrado directo a SFTP y Nextcloud desde su propia interfaz.

 [OPNsense — Cloud Backup](https://docs.opnsense.org/manual/how-tos/cloud_backup.html)

### 6.3 Restauración

Para restaurar la configuración en un VPS nuevo o reinstalado:

1. Copiar el fichero `config.xml` a `/conf/config.xml`.
2. Reiniciar OPNsense.
3. La configuración se carga automáticamente al arranque.

**Tiempo de recuperación estimado:** 15–30 minutos (levantar nuevo VPS + instalar OPNsense + restaurar config).

---

## 7. Propuesta de Producto Comercial

### 7.1 Paquete Base — "Cloud-Hub PYME"

|Incluido|Detalle|
|---|---|
|Despliegue de OPNsense en VPS|Instalación, configuración inicial, hardening.|
|Túneles VPN (hasta 10 peers)|WireGuard. Generación de perfil para cada empleado.|
|Firewall centralizado|Reglas personalizadas según necesidades del cliente.|
|Segmentación de red|Red interna `10.10.1.0/24` con control de acceso por peer.|
|Split-tunneling|Configuración por defecto para continuidad operativa.|
|2FA en panel de gestión|TOTP activado para la administración por SECCIÓN 9.|
|Backup automatizado|Cron diario con almacenamiento externo.|
|Soporte remoto mensual|Modificación de reglas, alta/baja de usuarios, monitorización básica.|

**Lo que el cliente necesita hacer:** Instalar la app WireGuard en cada equipo e importar el perfil `.conf` o escanear el QR que le proporciona SECCIÓN 9. Nada más.

### 7.2 Extras Facturables

|Servicio|Detalle|
|---|---|
|WAF (Cloudflare Pro)|Para clientes con web pública.|
|VPS de respaldo (failover)|Alta disponibilidad.|
|Full tunnel con IP fija de salida|Para clientes que necesiten whitelist de IP en servicios externos (CRM, bancos, etc.).|
|Ampliación de peers (>10)|Escalado de túneles VPN.|
|Auditoría de logs mensual|Informe de conexiones y eventos de seguridad.|

### 7.3 Modelo de Facturación Sugerido

|Concepto|Precio orientativo|
|---|---|
|Despliegue inicial (setup)|200–400 € (pago único)|
|Cuota mensual de gestión (hasta 10 peers)|80–150 €/mes|
|Peer adicional (a partir del 11)|5–10 €/mes por peer|

**Margen de SECCIÓN 9:** El coste de infraestructura por cliente es de ~5 €/mes (un VPS CX22). Si se cobra 100 €/mes de cuota, el margen bruto es del 95%. El valor está en el conocimiento, la gestión y la tranquilidad que se vende al cliente.

### 7.4 Argumento de Venta

> "Tu empresa tiene una red segura como la de una gran corporación, sin comprar hardware, sin contratos largos y sin necesitar un informático en plantilla. Nosotros lo gestionamos todo. Tú solo instalas una app en cada equipo."

---

## 8. Cómo lo Implementan las Empresas Medianas (Referencia)

Las empresas medianas que adoptan este modelo suelen seguir estas prácticas:

1. **Split-tunneling como estándar.** Solo el tráfico corporativo viaja por la VPN. La navegación personal del empleado sale directamente a internet.
2. **2FA obligatorio.** Combinación de contraseña + código TOTP para cualquier acceso administrativo a la red.
3. **Cada dispositivo como peer individual.** No se depende de routers locales ni de hardware en la sede del cliente. Cada equipo tiene su propio túnel.
4. **Alta disponibilidad con dos VPS.** Una instancia primaria y una réplica. Si la primaria falla, la secundaria toma el control.
5. **WireGuard como protocolo preferido.** Por rendimiento, simplicidad y estabilidad en conexiones móviles.
6. **Revocación instantánea.** Si un empleado deja la empresa o pierde un dispositivo, se elimina su peer del Hub en segundos y pierde todo acceso a la red.

---

## 9. Dudas Abiertas y Próximos Pasos

- **¿BYOD o equipos de empresa?** Si los empleados usan sus propios dispositivos, la distribución segura de perfiles WireGuard y la política de revocación son especialmente importantes.
- **¿Qué servicios internos necesita el cliente?** Carpetas compartidas (Samba/NFS), servidores de aplicaciones, bases de datos — cada uno puede requerir reglas de firewall específicas. En el modelo 100% VPS, estos servicios pueden correr en el propio VPS o en otro VPS dentro de la misma red.
- **Servicios internos en la nube:** Si el cliente necesita un servidor de ficheros o una aplicación interna, se puede desplegar como un segundo VPS en Hetzner dentro de la misma red privada, accesible solo a través del Hub. Esto mantiene el modelo 100% cloud.
- **Descubrimiento de red local (mDNS/impresoras):** En el modelo 100% VPS, los equipos de la oficina no comparten segmento de broadcast. Si necesitan descubrir impresoras por mDNS, se configuran las impresoras con IP fija y se accede por IP directa en lugar de por descubrimiento automático.
