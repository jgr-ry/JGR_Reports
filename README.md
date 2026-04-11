# JGR Reports

Sistema de **reportes y soporte in-game** para **FiveM**, con interfaz NUI, chat en vivo, historial y soporte **multi-framework** (QBCore, Qbox, ESX y modo standalone).

**Versión:** `1.0.0.0`  
**Autor:** JGR Studio  

---

## Características

- **Jugadores:** comando para crear reportes (título, descripción, prioridad) y ver staff en línea.
- **Staff:** panel con reportes activos, historial, búsqueda y chat por reporte.
- **Chat** en tiempo real entre jugador y staff (y visibilidad para otros staff en el mismo hilo).
- **Llamadas de voz** opcionales con **pma-voice** (canal de llamada temporal).
- **Historial** de reportes cerrados con motivo de cierre (staff, usuario, inactividad).
- **Cierre automático** si el reportante lleva **desconectado** más tiempo del configurado.
- **Estado en línea** del reportante en el panel de staff.
- **Idiomas:** español e inglés (`locales/es.lua`, `locales/en.lua`).
- **Base de datos:** importación automática de tablas si no existen (MySQL / oxmysql).

---

## Requisitos

| Dependencia | Uso |
|-------------|-----|
| **[oxmysql](https://github.com/overextended/oxmysql)** | Obligatorio |
| **qb-core** / **qbx_core** / **es_extended** | Según `Config.Framework` |
| **pma-voice** | Opcional (llamadas) |

- **FXServer** con artefactos recientes (recomendado `cerulean`).

---

## Instalación

1. Copia la carpeta del recurso en tu directorio `resources` (por ejemplo `[JGR]/JGR_Reports`).
2. Asegúrate de tener **oxmysql** iniciado **antes** que este recurso.
3. Añade en `server.cfg`:

   ```cfg
   ensure oxmysql
   ensure JGR_Reports
   ```

4. **Base de datos:** la primera ejecución puede crear las tablas automáticamente. También puedes importar manualmente `install.sql` en tu base de datos.
5. Edita **`config.lua`** (al menos `Config.Framework` y, si aplica, grupos de staff).
6. Reinicia el servidor o `ensure JGR_Reports`.

---

## Configuración rápida

Todo lo esencial está en **`config.lua`**.

### Framework (`Config.Framework`)

Un solo valor define el modo de ejecución y el recurso de export:

| Valor | Recurso usado |
|-------|----------------|
| `qb` | `qb-core` |
| `qbox` o `qbx` | `qbx_core` |
| `esx` | `es_extended` |
| `standalone` | Sin framework (identidad por `license`) |

Ejemplo Qbox:

```lua
Config.Framework = 'qbox'
```

Ejemplo ESX:

```lua
Config.Framework = 'esx'
```

### Idioma

```lua
Config.Locale = 'es'   -- o 'en'
```

### Comandos (por defecto)

| Comando | Quién | Descripción |
|---------|--------|-------------|
| `/report` | Jugadores | Crear reporte o abrir el chat si ya hay uno activo |
| `/reportes` | Staff | Panel de administración |

Los nombres se cambian con `Config.CommandPlayer` y `Config.CommandAdmin`.

### Permisos de staff

- **QB / Qbox:** `Config.AdminGroups` debe coincidir con los grupos ACE / permisos de QBCore (`HasPermission`).
- **ESX:** se comprueba `getGroup()` y el **nombre del job** frente a la misma lista.
- **Standalone:** usa `Config.StandaloneAce` (ACE) y/o `Config.StandaloneAdminLicenses` (lista de `license:...`).

Ejemplo ACE para standalone:

```cfg
add_ace group.admin jgr_reports.admin allow
```

### Otros ajustes

- `Config.AutoCloseOfflineMinutes` — minutos desconectado antes del cierre automático.
- `Config.StatusCheckIntervalMs` — intervalo del comprobador de inactividad / `serverId`.
- `Config.VoiceChannelBase` — referencia interna de voz (llamadas con pma-voice).

---

## Estructura del proyecto

```
JGR_Reports/
├── bridge/
│   ├── cl_bridge.lua      # Cliente: framework + callbacks
│   └── sv_bridge.lua      # Servidor: framework + comandos + callbacks
├── client/
│   └── client.lua
├── server/
│   └── server.lua
├── locales/
│   ├── en.lua
│   └── es.lua
├── html/                  # NUI (HTML / CSS / JS)
├── config.lua
├── locale_shared.lua
├── install.sql
├── fxmanifest.lua
└── README.md
```

---

## Base de datos

- Tablas: `jgr_reports`, `jgr_report_messages`.
- La columna **`citizenid`** almacena el identificador unificado del jugador (citizenid en QB, `identifier` en ESX, `license:` en standalone).

---

## Solución de problemas

- **No cargan los callbacks / errores de framework:** revisa que `Config.Framework` coincida con el recurso real (`qb-core`, `qbx_core`, `es_extended`) y el orden de `ensure` en `server.cfg`.
- **Staff no puede abrir `/reportes`:** revisa `AdminGroups` (QB) o grupo/job (ESX) o ACE/licencias (standalone).
- **Sin llamadas de voz:** instala y arranca **pma-voice**; si no está, el script no debería fallar (usa `pcall`).
- **Textos mezclados:** confirma `Config.Locale` y que existan las claves en `locales/*.lua`.

---

## Créditos

- **JGR Studio** — desarrollo y diseño del recurso.
- Comunidad **FiveM** y autores de **oxmysql**, frameworks y **pma-voice**.

---

## Licencia

Uso y redistribución según las condiciones que defina **JGR Studio**. Si publicas en GitHub, añade un archivo `LICENSE` acorde a tu política.

---

¿Dudas o mejoras? Abre un **issue** o un **pull request** en el repositorio.
