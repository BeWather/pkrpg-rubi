# AGENTS.md — rubi4 (Pokémon Rubi)

Instrucciones persistentes del proyecto para cualquier agente de IA.

| | |
|---|---|
| **Proyecto** | rubi4 — motor de batalla + overworld estilo Pokémon 2D |
| **Motor** | Godot 4.7.2 stable (`B:\Users\Terraplanista\Godot\Godot_v4.7.2\Godot_v4.7.2-stable_win64.exe`) |
| **Lenguaje** | GDScript 2.0 — tipado estático **obligatorio** |
| **Renderer** | GL Compatibility |
| **Viewport** | 720×480, stretch mode `viewport`, scale 3.0 |
| **Escena principal** | `res://escenas/administrador_mapa.tscn` |
| **Idioma** | **Responde siempre en español** |
| **Docs oficiales** | https://docs.godotengine.org/en/latest/ |

---

## Plataforma objetivo

- El proyecto se desarrolla **solo para PC (escritorio)**. No hacer trabajo orientado a otros targets salvo petición explícita.
- Cualquier tarea de exportación (Android, web, consolas…) se trabaja **únicamente en una rama dedicada** (p. ej. `export/android`), nunca en la rama principal.
- En la rama principal: no introducir rutas alternativas ni lógica específica de exportación (copias `user://`, controles táctiles, escalados de viewport móvil…). El código de export existente se mantiene tal cual, sin ampliarlo.

---

## Reglas de GDScript 2.0

| Regla | Ejemplo |
|---|---|
| **Tipado estático** | `var health: int = 100` |
| **Refs de nodos** | `@onready var sprite: Sprite2D = $Sprite2D` |
| **Señales nuevas** | `signal_name.connect(_on_signal)` — nunca `connect("signal_name", ...)` |
| **Callables** | `var cb: Callable = func(): pass` |
| **Await** | `await tween.finished` — nunca `yield(...)` |
| **Lambdas** | `func(x): return x * 2` para callbacks rápidos |
| **StringName** | `&"node_path"` en lookups frecuentes (perf) |
| **Anotaciones** | `@export`, `@onready`, `@icon`, `@tool` bien puestos |

---

## Arquitectura

- **Composición sobre herencia** — usa componentes (Nodes) en vez de jerarquías profundas.
- **SQLite seguro** — con `godot-sqlite`, usa queries preparadas o inserción por diccionario; nunca concatenas strings.
- **Naming** — `snake_case` para variables/funciones, `PascalCase` para clases.
- **Cacheo de nodos** — `@onready` para refs; nunca `get_node()` dentro de loops.
- **Naming del proyecto** — el código de gameplay, nombres de escenas y variables están en **español** (`administrador_mapa.gd`, `sistema_guardado.gd`, `evento_pc_centro.gd`). Mantenlo en código nuevo salvo que el módulo ya use inglés.
- **Escenas declarativas** — prefiere `.tscn` con nodos/propiedades editables en el editor sobre árboles construidos en scripts. Los scripts son para el comportamiento; las entidades dinámicas instancian `PackedScene` authored. Los importadores **deben preservar las ediciones de escena existentes** por defecto.
- **Acceso a datos** — todo dato persistente (especies, movimientos, entrenadores) pasa por `DatabaseManager` (SQLite), nunca I/O ad hoc.
- **Config estática** — en JSON bajo `BaseDatos/` (`config_encuentros.json`, `lista_entrenadores.json`, `temas_musicales.json`), no hardcodeada en scripts.
- **Localización** — el texto de cara al jugador pasa por `DialogManager` y recursos `.translation` (es por defecto, en fallback).

### Autoloads (`project.godot`)

| Nombre | Script | Responsabilidad |
|---|---|---|
| `Singleton` | `res://scripts/singleton.gd` | Estado global y servicios |
| `SistemaGuardado` | `res://scripts/sistema_guardado.gd` | Guardado/carga de partidas |
| `DatabaseManager` | `res://BaseDatos/database_manager.gd` | Capa de acceso a SQLite |
| `DialogManager` | `res://scripts/dialog_manager.gd` | Presentación de diálogos y texto |
| `McpInteractionServer` | `res://dev/mcp/mcp_interaction_server.gd` | Puente de runtime para el MCP de Godot |
| `DebugArranque` | `res://dev/debug_arranque.gd` | Arranque F6 desde una escena de mapa |

> Ojo: `openspec/project.md` está desactualizado respecto a esto (lista 4 autoloads y afirma que no hay framework de test).

---

## Performance y elección de loop

| Usa | Contexto |
|---|---|
| `_physics_process` | Movimiento en grid, lógica de juego determinista, tiles — evita jitter de píxel |
| `_process` | Tracking de cámara, pulido visual, updates de UI, efectos dependientes de framerate |
| ❌ `get_node()` en loop | Cachea con `@onready` |

---

## Verificación y pruebas

**Regla dura: nunca mates ni cierres procesos de Godot.** El editor o el juego pueden estar abiertos.

| Cuándo | Herramienta |
|---|---|
| Pruebas unitarias / integración | **gdUnit4** en `test/` (595 suites) — skill `godot-runtime-testing` |
| Carga del proyecto | `--headless --path <root> --quit` |
| Editar/inspeccionar escenas y scripts | **MCP `godot`** (ver abajo) |
| Regresión visual de batalla | sin harness automático: usar el harness manual `escenas/batalla/README_PRUEBA.md` (F6) |

Carga la skill `godot-runtime-testing` con la herramienta `skill` antes de hacer el trabajo.

### MCP `godot` (157 tools)

Servidor local configurado en `.opencode/opencode.jsonc` → `mcp.servers.godot`. Herramientas útiles:

- `validate_script` / `validate_scripts` — errores de sintaxis y tipos sin arrancar el juego (resuelve autoloads correctamente, a diferencia de `--check-only`).
- `read_scene` — árbol de nodos + propiedades de un `.tscn` en JSON.
- `modify_scene_node` / `attach_script` / `remove_scene_node` / `create_resource` — edición de escenas sin abrir el editor.
- `read_project_settings` / `modify_project_settings` / `manage_input_map` / `manage_autoloads` — `project.godot` estructurado.
- `run_project` + `get_debug_output` + `game_get_errors` / `game_get_logs` — ejecución instrumentada.
- `game_eval` — ejecutar GDScript arbitrario contra el juego en marcha.

> `GODOT_MCP_ALLOWED_DIRS` restringe `run_project` a `B:\godot\rubi4`.

### SQLite

Acceso directo por CLI, sin wrapper: `sqlite3 "B:\godot\rubi4\BaseDatos\poke.db"`.
Schema, ejemplos y relaciones FK en `BaseDatos/SCHEMA_REFERENCE.md` (14 tablas: `Pokemon`, `PokemonInstancias`, `Movimientos`, `PokemonMovimientos`, `Tipos`, `Naturalezas`, `Habilidades`, `Objetos`…).
Campos JSON: `movimientos_json`, `marcas_json`, `cintas_json` → parsear en Godot con `JSON.parse()`.

---

## Documentos clave del repositorio

| Documento | Para qué |
|---|---|
| `openspec/project.md` + `openspec/config.yaml` | Contexto y reglas del flujo spec-driven (**parcialmente desactualizado**) |
| `openspec/changes/<id>/` | Cambios en curso: `proposal.md`, `design.md`, `tasks.md`, `specs/*/spec.md` |
| `documentacion/` | 150+ análisis y diseños (español) |
| `docs/api_warp.md`, `docs/android-export.md` | APIs concretas de warp y de exportación |
| `readme.md` | Notas de desarrollo por sistema |
| `.atl/sdd-init-rubi4.md` | Snapshot de arquitectura, plugins, riesgos de exportación |
| `BaseDatos/SCHEMA_REFERENCE.md` | Schema de la BD |
| `escenas/batalla/README_PRUEBA.md` | Harness manual de batalla (F6) |
| `addons/tilemap_inspector/editores/` | Editores del plugin (diálogos, encuentros, temas musicales, POI, posiciones de battlers…) |

---

## NPC: rango de paseo anclado al origen

Los mapas quedan instanciados (se ocultan/muestran al cambiar de mapa) y `npc_base.reinicializar_como_recien_agregado()` corre cada vez que se ocultan. El rango de paseo (`rango_ini`/`rango_fin`) se calcula **siempre** desde `celda_origen` (celda inicial), nunca desde `coord_celda`; si no, el NPC deriva `rango` celdas en cada visita. Si un NPC se recoloca a propósito (ej. abuelo de la guardería), actualizar también `celda_origen`.

## Preview de batalla original

Para reproducir animaciones y audio originales de Ruby en mGBA, cargá la skill
`.agents/skills/legacy-battle-player/SKILL.md`. La CLI y el configurador visual están
en `herramientas/legacy_battle_player/`; usan el mismo JSON en Ubuntu y Windows 11.
No confundir este flujo con las pruebas de escenas de Godot.

**En esta máquina (Windows 11) ya está todo instalado y probado**: mGBA en
`B:\tools\mGBA\mGBA-0.10.5-win64\mGBA.exe`, ROM harness compilada en
`B:\tools\battle_preview\pokeruby_debug_modern_preview.gba`. Rutas, receta de recompilación en WSL, bugs
ya corregidos y depuración por volcado de frames: `herramientas/legacy_battle_player/ENTORNO_WINDOWS.md`.
El código del harness vive sin commitear en `B:\github\decomp\pokeruby`.
