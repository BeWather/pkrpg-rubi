# Notas de Desarrollo - Pokémon Rubi

## Pantalla de Inicio

### Descripción
La pantalla de inicio es la primera pantalla que se muestra al iniciar el juego, diseñada para:
- Mostrar el banner del juego con branding visual
- Requerir confirmación del usuario mediante la tecla Enter
- Presentar el menú principal con opciones para continuar partida, nueva partida u opciones

### Escena Principal
- **Escena**: `escenas/pantalla_inicio.tscn`
- **Script**: `escenas/pantalla_inicio.gd`
- **Configuración**: Cambiada en `project.godot` (run/main_scene)

### Funcionalidades

#### Navegación
- **Flechas Arriba/Abajo**: Mueven el cursor entre opciones
- **Enter (btn_menu)**: Confirma la selección actual
- **Back (btn_cancel)**: Vuelve al banner o cierra el juego

#### Opciones del Menú
1. **Continuar Partida**:
   - Carga el último archivo de guardado si existe
   - Restaura equipo, items, ubicación y todo el estado del juego
   - Si no hay partidas guardadas, muestra un mensaje de error

2. **Nueva Partida**:
   - Crea un nuevo estado de juego desde cero
   - Limpia cualquier archivo de guardado existente
   - Inicializa al jugador en Villa Raíz o Pueblo Escaso con equipo inicial
   - Restaura configuración por defecto

3. **Opciones**:
   - Abre la pantalla de configuración del juego (ventana_opciones.tscn)
   - Permite ajustar velocidad de texto, audio, controles, etc.
   - Puede devolverse a la pantalla de inicio

#### Transiciones
- Efecto de fade a negro entre escenas
- Bloqueo de inputs durante transiciones
- Sistema limpio y rápido (0.3 segundos)

### Integración con SistemaGuardado
- Usa el autoload `SistemaGuardado` para detectar y cargar partidas
- Los métodos utilizados son:
  - `has_partida_guardada()`: Verifica si existe un archivo de guardado
  - `cargar_partida()`: Carga los datos del archivo guardado
  - `crear_partida_nueva()`: Crea un nuevo estado de juego
  - `guardar_partida()`: Guarda el estado actual (llamado automáticamente)

### Estilo Visual
- **Fuente**: pokemon-rs.ttf (15px)
- **Colores**: #2a2a2a (texto), #737373 (sombra)
- **Menús**: NinePatchRect con menu_box_1.png
- **Cursor**: cursor-menu.png
- **Banner**: groudon1x140.png

### Manejo de Errores
- **Sin partidas guardadas**: Muestra "No hay partidas guardadas"
- **Archivo de guardado corrupto**: Se trata como "sin partidas guardadas"
- **SistemaGuardado no disponible**: Muestra error y cierra el juego
- **Transiciones fallidas**: Se queda en la pantalla de inicio con error en log

### Archivos Creados/Modificados
- Creados: `escenas/pantalla_inicio.tscn`, `escenas/pantalla_inicio.gd`
- Modificados: `scripts/sistema_guardado.gd` (agregados has_partida_guardada() y crear_partida_nueva()), `project.godot` (escena principal)

### Notas de Implementación
- El código sigue el patrón de menu_pausa.tscn existente en el proyecto
- Se usan inputs existentes sin necesidad de nuevos bindings
- El diseño prioriza simplicidad y mantenibilidad sobre efectos visuales complejos
- Se implementa manejo robusto de errores para evitar crashes

- **Engine**: Godot 4.7.1
- **Nombre**: Pokemon Rubi
- **Rendering**: GL Compatibility
- **Resolución**: 960x640 (escalado x4), 720x480 (escalado viewport x3)
- **Tile Size**: 16px
- **Icono**: groudon1x140.png

## Arquitectura Principal

### Scene Manager

- **Escena principal**: `administrador_mapa.tscn` (uid://b5sfh2dac3bop)
- **Script principal**: `scripts/administrador_mapa.gd`
- **Singleton**: `scripts/singleton.gd` (autoload)

### Sistema de Mapas

- **Gestión centralizada**: Dictionary `mapas_node2d` en Singleton
- **Conexiones**: configuradas en `escenas/Overworld.tscn` (posición en el mundo) y por warps dentro de cada mapa
- **Tipos de mapa**: Exteriors, interiores, rutas
- **Sistema de puertas**: Enum + Array de escenas preloaded
- **Carga dinámica**: queue_free + instantiate pattern

#### Mapas Disponibles

```txt
villa_raiz, villa_raiz_casa1_piso1/2, villa_raiz_casa2_piso1/2
villa_raiz_laboratorio, ruta_101, ruta_102, ruta_103
pueblo_escaso, pueblo_escaso_casa_1/2, pueblo_escaso_centro, pueblo_escaso_shop
frente_batalla
```

### Sistema de Jugador

- **Escena**: `escenas/avatares/CB2_Aura.tscn`
- **Instanciación dinámica**: en AdministradorMapa._ready()
- **Input handling**: En administrador_mapa.gd
- **Focus cámara**: Asignado via Singleton.set_foco_camara()

### Sistema de NPCs

- **Script base**: `scripts/npc/npc_base.gd` (instancia `escenas/avatares/npc_base.tscn`)
- **Enum movimientos**: 35+ tipos de comportamiento
- **Recursos**: npc_001.tres a npc_028.tres
- **Patrones**: Sin movimiento, mirar, pasear, caminar, rotación
- **Autogenerador**: `generar_npc_tres.gd`

### Sistema de Pokemon

- **Clase base**: `BaseDatos/basepoke.gd` (RefCounted)
- **Base datos**: SQLite en `BaseDatos/poke.db`
- **Addon**: godot-sqlite plugin
- **Movimientos**: `BaseDatos/bd_movimientos.gd`

### Sistema de Batalla

- **Escena**: `escenas/batalla/batalla.tscn`
- **Menús**: batalla_menu_1.tscn, batalla_menu_mov.tscn
- **UI elementos**: cuadro_ps_jugador.tscn, cuadro_ps_rival.tscn

#### Animaciones de movimientos en batalla

- **Animaciones nativas** (las que usa el juego): escenas en `escenas/batalla/animaciones_nativas/` y adaptador en
  `scripts/battle/animations/nativa/`; política en `MoveAnimationRegistry` y opción `batalla/animaciones_nativas` de
  `project.godot`. Historia y validación: `documentacion/piloto_animaciones_nativas.md`.
- **VM legada** (`scripts/battle/animations/sequence/`, intérprete del bytecode del decomp): **obsoleta** desde el
  2026-10-27; solo se ejecuta por configuración o en laboratorio, comparador y tests. Ver
  `scripts/battle/animations/sequence/README.md`.

## Controles de Input

```txt
btn_arriba: UP_ARROW
btn_abajo: DOWN_ARROW
btn_derecha: RIGHT_ARROW
btn_izquierda: LEFT_ARROW
btn_accion: D key
btn_cancela: S key
btn_menu: TAB key
btn_foco_cam: - key
```

## Estructura de Carpetas

```txt
Audio/ - BGM, BGS, ME, SE
BaseDatos/ - Scripts de datos, DB, traducciones
escenas/ - Todas las escenas (.tscn)
  ├── avatares/ - NPCs y personajes
  ├── batalla/ - Sistema de combate
  └── mapas/ - Mapas y animaciones
fuentes/ - Pokemon fonts (.ttf)
graficos/ - Sprites, tiles, assets visuales
herramientas/ - Utilidades desarrollo
UI/ - Interfaz usuario
scripts/ - Scripts globales
```

## Sistemas de Audio

- **BGM**: Loop con BucleIni/BucleFin metadata
- **SFX**: AudioStreamPlayer2D para efectos
- **Configuración**: Enum NivelAudio en Singleton

## Sistema de Localización

- **Idiomas**: ES (fallback), EN
- **Archivos**: dialogos.csv → .translation
- **Gestión**: TranslationServer

## Patrones de Código

### Metadatos

- **Grupo "Metadatos"**: TileMapLayer con datos especiales
- **Grupo "Cartel"**: Elementos interactivos
- **Grupo "Personaje"**: Todos los personajes
- **Grupo "PastoAlto1"**: Animaciones de pasto

### Animaciones de Entorno

- **Pasto pisado**: `pasto_pisado.tscn` con auto-cleanup
- **Polvo salto**: `polvo_salto.tscn`
- **Flecha salida**: `fecha_salida_abajo.tscn`

### Escaleras/Transiciones

- **Script**: `scripts/tile_escalera.gd`
- **Patrón**: destino + posición + dirección + dar_paso

## Plugins/Addons

- **godot-sqlite**: Base datos SQLite
- **pk-rpg-tool**: Herramientas RPG PKM (kit completo para desarrollo Pokemon-style)

## Debugging/Desarrollo

- **Posición inicial configurable**: Comentarios en administrador_mapa.gd
- **Mapas de prueba**: Diferentes spawn points
- **Generador NPCs**: Automatización de .tres
- **Documentación**: estructura_frente_batalla.md

## Convenciones de Nomenclatura

- **Escenas**: snake_case.tscn
- **Scripts**: snake_case.gd
- **Recursos**: snake_case.tres
- **Sprites**: snake_case.png
- **Audio**: PascalCase/snake_case.format

## Notas de Rendimiento

- **Y-Sort**: Habilitado en escenas principales
- **Texture Filter**: 0 (pixel perfect)
- **Queue_free pattern**: Para cambios de mapa
- **Preload**: Escenas y recursos frecuentes

## Estado Actual (v0.3.0)

- ✅ Sistema de mapas funcional
- ✅ NPCs con IA básica
- ✅ Sistema de batalla implementado
- ✅ Audio y localización
- ✅ Plugin pk-rpg-tool funcional
- 🔄 Sistema pokémon en desarrollo

