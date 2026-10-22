# JGR Reports

Sistema de **reportes y soporte in-game** para FiveM: los jugadores abren un reporte, el staff lo atiende desde un panel con chat en vivo, historial y llamadas de voz opcionales.

`Versión 1.1.0` · `QBCore · Qbox · ESX · Standalone (ox_core)` · `oxmysql`

---

## Características

- **Jugadores**: `/report` abre un formulario (título, descripción, prioridad Baja/Media/Alta) con el staff conectado; si ya tienes un reporte activo, abre su chat.
- **Staff**: `/reportes` abre el panel con reportes activos (con estado en línea del jugador), historial de los 50 últimos cerrados y búsqueda.
- **Chat en tiempo real** entre jugador y staff; el resto del staff conectado también ve los mensajes.
- **Asignación**: al abrir un reporte, el staff lo toma (`En progreso`) y el jugador recibe un aviso.
- **Llamadas de voz** opcionales con **pma-voice** (canal de llamada temporal; sin pma-voice no falla).
- **Cierre** por staff, por el propio jugador o **automático** si el jugador lleva desconectado más de `Config.AutoCloseOfflineMinutes`.
- **Historial** con motivo de cierre (staff, usuario, inactividad) y quién lo cerró.
- **Base de datos**: crea las tablas automáticamente la primera vez y añade columnas nuevas al actualizar.
- **Idiomas**: español e inglés.

## Requisitos

| Recurso | ¿Obligatorio? | Uso |
|---|---|---|
| [oxmysql](https://github.com/overextended/oxmysql) | **Sí** | Base de datos |
| `qbx_core` / `qb-core` / `es_extended` / `ox_core` | No | Se detecta solo; sin framework funciona en modo standalone |
| `pma-voice` | No | Llamadas de voz staff ↔ jugador |

## Instalación

1. Copia la carpeta con el nombre **exacto** `JGR_Reports` (si se renombra, el recurso se detiene).
2. Base de datos: las tablas `jgr_reports` y `jgr_report_messages` se crean solas al primer arranque. Si lo prefieres, importa `install.sql` a mano.
3. Añade al `server.cfg`, **después** de oxmysql y del framework:
   ```cfg
   ensure oxmysql
   ensure qb-core        # o qbx_core / es_extended / ox_core (opcional)
   ensure pma-voice      # opcional
   ensure JGR_Reports
   ```
4. Revisa `config.lua` (sobre todo `Config.AdminGroups` para tu staff).

## Configuración

| Opción | Por defecto | Descripción |
|---|---|---|
| `Config.Framework` | `'auto'` | `'auto'`, `'qb'`, `'qbox'` (o `'qbx'`), `'esx'` o `'standalone'`. En `auto` detecta `qbx_core` → `qb-core` → `es_extended` → `ox_core` → standalone |
| `Config.Locale` | `'es'` | `'es'` o `'en'` |
| `Config.CommandPlayer` | `'report'` | Comando de jugadores |
| `Config.CommandAdmin` | `'reportes'` | Comando del panel de staff |
| `Config.AdminGroups` | `{ 'mod', 'admin', 'god' }` | Grupos de staff (ver tabla de compatibilidad) |
| `Config.StandaloneAce` | `'jgr_reports.admin'` | ACE de staff en standalone / ox_core |
| `Config.StandaloneAdminLicenses` | `{}` | Lista de `license:...` con acceso de staff en standalone |
| `Config.AutoCloseOfflineMinutes` | `10` | Minutos desconectado antes de cerrar el reporte |
| `Config.StatusCheckIntervalMs` | `60000` | Cada cuánto se comprueba el estado de los reportantes |
| `Config.VoiceChannelBase` | `8000` | Las llamadas usan un canal aleatorio entre este valor y +1999 |

## Compatibilidad con frameworks

| | QBCore | Qbox | ESX Legacy | Standalone / ox_core |
|---|---|---|---|---|
| Identificador guardado en la columna `citizenid` | `citizenid` | `citizenid` | `xPlayer.identifier` | `license:...` |
| Nombre del personaje (panel de staff) | `charinfo` | `charinfo` | `xPlayer.getName()` | Nombre de FiveM |
| Staff | `QBCore.Functions.HasPermission(src, Config.AdminGroups)` | ACE `group.<grupo>` o `exports.qbx_core:HasPermission` | `getGroup()` o nombre del job en `Config.AdminGroups` | ACE `Config.StandaloneAce` o `Config.StandaloneAdminLicenses` |
| Notificaciones | `QBCore:Notify` | `exports.qbx_core:Notify` | `esx:showNotification` | Notificación nativa de GTA |
| Comandos | `QBCore.Commands` | `RegisterCommand` | `RegisterCommand` | `RegisterCommand` |

Ejemplo de ACE para staff en standalone:

```cfg
add_ace group.admin jgr_reports.admin allow
```

> La columna se sigue llamando `citizenid` en todos los frameworks; en ESX guarda el `identifier` y en standalone la licencia. Si cambias de framework, los reportes antiguos quedarán asociados al identificador anterior.

## Comandos

| Comando | Quién | Descripción |
|---|---|---|
| `/report` | Jugadores | Crear reporte o abrir el chat del activo |
| `/reportes` | Staff | Panel de reportes |

## Actualizaciones

Al arrancar, el servidor comprueba si hay una versión nueva (lista central de versiones de JGR) y lo avisa en la consola con tu versión, la última y el enlace de descarga. Para desactivar el aviso, añade al `server.cfg`:

```cfg
set jgr_versioncheck 0
```

## Solución de problemas

- **En consola sale `Framework: standalone` y usas un framework**: inicia el framework **antes** que `JGR_Reports` o fíjalo con `Config.Framework`.
- **El staff no puede abrir `/reportes`**: revisa `Config.AdminGroups` (QB/ESX), los ACE `group.<grupo>` (Qbox) o `Config.StandaloneAce` / licencias (standalone).
- **No hay voz en las llamadas**: instala y arranca `pma-voice`.

## Changelog

### 1.1.0
- Compatibilidad con **QBCore, Qbox, ESX Legacy y standalone/ox_core** con detección automática (`Config.Framework = 'auto'`).
- **Corregido**: en Qbox se usaba `exports['qbx_core']:GetCoreObject()`, que no existe: no se cargaba ningún jugador y el script no funcionaba. Ahora usa `exports.qbx_core:GetPlayer`, `GetPlayerByCitizenId`, `Notify` y permisos ACE.
- **Seguridad**: cualquier jugador podía enviar mensajes marcados como `[Staff]` y escribir en reportes ajenos. Ahora el servidor decide si el mensaje es de staff y solo deja escribir en el propio reporte activo.
- **Seguridad**: contestar, rechazar y colgar llamadas se valida en el servidor (antes se podía meter a cualquier jugador en un canal de voz o colgar llamadas ajenas).
- **Seguridad**: los nombres de jugador en el chat se escapan en la NUI (un nombre con HTML se ejecutaba en el panel del staff).
- **Corregido**: tomar un reporte ya cerrado lo volvía a poner `En progreso`.
- **Corregido**: el límite de un reporte activo por jugador solo lo aplicaba el comando; ahora también el servidor (más 30 s entre reportes).
- La prioridad se valida (`Baja`, `Media`, `Alta`).
- Al desconectarse un participante, la llamada se corta para el otro.
- `Config.VoiceChannelBase` ahora se usa de verdad para elegir el canal.
- Comprobador de versiones común de JGR (`server/version_check.lua`), desactivable con `set jgr_versioncheck 0`.

### 1.0.0
- Versión inicial.

## Estructura

```
JGR_Reports/
├── bridge/
│   ├── sh_bridge.lua      # Detección de framework (compartido)
│   ├── cl_bridge.lua      # Cliente: notificaciones + callbacks
│   └── sv_bridge.lua      # Servidor: jugadores, staff, comandos, callbacks
├── client/client.lua
├── server/
│   ├── init.lua           # Comprobación del nombre del recurso
│   ├── server.lua
│   └── version_check.lua  # Comprobador de versiones común JGR
├── locales/ (es, en)
├── html/                  # NUI
├── config.lua
├── locale_shared.lua
└── install.sql
```

## Soporte y créditos

Desarrollado por **JGR** · GitHub: [jgr-ry](https://github.com/jgr-ry).

Para dudas o errores abre un *issue* en [github.com/jgr-ry/JGR_Reports](https://github.com/jgr-ry/JGR_Reports).
