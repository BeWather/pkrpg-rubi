@tool
extends Node2D
class_name TPTileDataMap

# ============================================================
# ENUM DE BANDERAS — referencia estática para scripting
#
# Cada valor es la MÁSCARA de bit (1 << bit_index), NO el índice.
# Debe mantenerse sincronizado con tile_data_map_flags_config.json:
#   - El "bit_index" del JSON debe coincidir con el bit usado aquí.
#
# Cuando añadas una bandera nueva en el plugin editor:
#   1. Anota el bit_index que asignó el plugin (se ve en el JSON).
#   2. Añade una entrada aquí con el valor  1 << bit_index.
#   3. Añade un comentario descriptivo.
#
# Uso en scripts:
#   if mapa.has_flag(celda, TPTileDataMap.Flags.BLOQUEO):
#       pass  # celda bloqueada
#   mapa.set_flag(celda, TPTileDataMap.Flags.SURF)
#   mapa.clear_flag(celda, TPTileDataMap.Flags.SURF)
# ============================================================
enum Flags {
	# --- AÑADE AQUÍ las banderas nuevas que crees en el plugin ---
	# EJEMPLO   = 4,   # 1 << 2  ·  Descripción de la bandera
	BLOQUEO              = 1,			# 1 << 0  .   	# Bloquea el paso del jugador
	SURF                 = 2,			# 1 << 1  .   	# Zona navegable con Surf
	HIERBA_ALTA          = 4,			# 1 << 2  .   	# Zona de hierba alta (encuentros salvajes)
	BORDE_ARRIBA         = 8,			# 1 << 3  .   	# Zona de relieve que permite paso solo desde abajo hacia arriba (salto)
	BORDE_ABAJO          = 16,			# 1 << 4  .  	# Zona de relieve que permite paso solo desde arriba hacia abajo (caída)
	BORDE_IZQUIERDA      = 32,			# 1 << 5  . 	# Zona de relieve que permite paso solo desde derecha hacia izquierda (salto)
	BORDE_DERECHA        = 64,			# 1 << 6  . 	# Zona de relieve que permite paso solo desde izquierda hacia derecha (salto)
	CAPA_SUPERIOR        = 128,			# 1 << 7  . 	# Zona que eleva al jugador al entrar al tile (ej. escaleras)
	CAPA_INFERIOR        = 256,			# 1 << 8  . 	# Zona que desciende al jugador al entrar al tile (ej. escaleras)
	BLOQUEO_ARRIBA       = 512,			# 1 << 9  . 	# Zona que bloquea el paso hacia arriba
	BLOQUEO_ABAJO        = 1024,		# 1 << 10 . 	# Zona que bloquea el paso hacia abajo
	BLOQUEO_IZQUIERDA    = 2048,		# 1 << 11 . 	# Zona que bloquea el paso hacia la izquierda
	BLOQUEO_DERECHA      = 4096,		# 1 << 12 . 	# Zona que bloquea el paso hacia la derecha
	HIERBA_MAS_ALTA      = 8192,		# 1 << 13 . 	# Zona de hierba más alta (encuentros salvajes + animación diferente)
	SOLO_CAMINAR         = 16384,		# 1 << 14 . 	# Zona que solo permite caminar (bloquea correr, bicicleta, etc.)
	REFLEJO              = 32768,		# 1 << 15 .		# Agua en calma; puede mostrar reflejos y FX suaves
	AGUA_SALPICA         = 65536,		# 1 << 16 .		# Superficie de agua que salpica
	BICI_DIR_HORIZONTAL  = 131072,		# 1 << 17 .		# Tile pensado para orientación horizontal de bici
	BICI_DIR_VERTICAL    = 262144,		# 1 << 18 .		# Tile pensado para orientación vertical de bici
	BICI_ACRO_SALTO      = 524288,		# 1 << 19 .		# Tile pensado para salto de bici acrobática
	ARENA_HUELLA         = 1048576,		# 1 << 20 .		# Superficie de arena que deja huellas
	DESIERTO             = 2097152,		# 1 << 21 .		# Arena de desierto: encuentros, arena a los pies y huellas
	HIERBA_CENIZA        = 4194304,		# 1 << 22 .		# Hierba alta cubierta de ceniza volcánica: se limpia al pisarla
	PUENTE_BAJO          = 8388608,		# 1 << 23 .		# Puente sobre agua, altura 1 (GBA bridge type 1): reflejo-silueta +12 px
	PUENTE_MEDIO         = 16777216,	# 1 << 24 .		# Puente sobre agua, altura 2 (GBA bridge type 2): reflejo-silueta +28 px
	PUENTE_ALTO          = 33554432,	# 1 << 25 .		# Puente sobre agua, altura 3 (GBA bridge type 3): reflejo-silueta +44 px
	PUENTE_MADERA        = 67108864,	# 1 << 26 .		# Puente de madera que vibra y suena al pisarlo (MB_FORTREE_BRIDGE, Ciudad Arborada)
	CUESTA_BARRO         = 134217728,	# 1 << 27 .		# Cuesta de barro (MB_MUDDY_SLOPE, Ruta 111): solo se sube al norte en bici de carrera a máxima velocidad; si no, resbala al sur
	SUELO_AGRIETADO      = 268435456,	# 1 << 28 .		# Suelo agrietado (MB_CRACKED_FLOOR, Cueva Granito): se rompe al pisarlo; solo se cruza en bici de carrera a máxima velocidad
	AGUJERO              = 536870912,	# 1 << 29 .		# Agujero en el suelo (MB_CRACKED_FLOOR_HOLE): el jugador cae al piso inferior
	MOSTRADOR            = 1073741824,	# 1 << 30 .		# MB_COUNTER: permite interactuar con un NPC una celda más allá
	CIMA_MONTANA         = 2147483648,	# 1 << 31 .		# Cima de montaña (MB_MOUNTAIN_TOP, cima del Monte Cenizo): terreno de batalla MONTANA
	ENCUENTRO_INTERIOR   = 4294967296,	# 1 << 32 .		# Encuentro en interior (MB_INDOOR_ENCOUNTER, mapas subterráneos): terreno de batalla EDIFICIO
	PUNTO_ELEVADO        = 8589934592,	# 1 << 33 .		# Punto elevado: el personaje/NPC gana +10 de z_index (offset_elevacion) al pisarlo sin cambiar de capa de datos,
	# --- Movimiento forzado del suelo (ForcedMovement_* de pokeruby; ver scripts/overworld/suelo_forzado.gd) ---
	RESBALADIZO          = 17179869184,	# 1 << 34 .		# Suelo resbaladizo (MB_ICE / MB_TRICK_HOUSE_PUZZLE_8_FLOOR): sigue deslizando en la dirección en que miraba hasta chocar o salir de la zona
	EMPUJE_ARRIBA        = 34359738368,	# 1 << 35 .		# Cinta transportadora al norte (MB_WALK_NORTH); con EMPUJE_DESLIZANTE = MB_SLIDE_NORTH
	EMPUJE_ABAJO         = 68719476736,	# 1 << 36 .		# Cinta transportadora al sur (MB_WALK_SOUTH / MB_SLIDE_SOUTH)
	EMPUJE_IZQUIERDA     = 137438953472,	# 1 << 37 .		# Cinta transportadora al oeste (MB_WALK_WEST / MB_SLIDE_WEST)
	EMPUJE_DERECHA       = 274877906944,	# 1 << 38 .		# Cinta transportadora al este (MB_WALK_EAST / MB_SLIDE_EAST)
	EMPUJE_DESLIZANTE    = 549755813888,	# 1 << 39 .		# Variante MB_SLIDE_*: a velocidad de carrera, sin animación de paso y sin girar al personaje (junto a un EMPUJE_*)
	TIERRA_PIES          = 1099511627776,	# 1 << 40 .		# Tierra a los pies (jugador y NPC): sprite de tierra que acompaña cada paso sobre el tile
	AGUA_PIES            = 2199023255552,	# 1 << 41 .		# Agua a los pies (charcos): animación de los pies mientras se esté sobre el tile (también parado), sin ondas ni reflejo
	CASCADA              = 4398046511104,	# 1 << 42 .		# Cascada (MB_WATERFALL): en surf empuja hacia el sur; se sube con el movimiento de campo CASCADA (arrastra hacia el norte mientras la celda la tenga)
	PENDIENTE_ACROBATICA = 8796093022208,	# 1 << 43 .		# Pendiente con baches (MB_BUMPY_SLOPE, Desfiladero): no se pisa a pie ni en bici de carrera ni con wheelie rodando; solo se entra con los saltitos del wheelie de la bici acrobática. Encima el wheelie no se deshace
	AGUA_TERMAL          = 17592186044416,	# 1 << 44 .		# Agua termal (MB_HOT_SPRINGS, estanque de Pueblo Lavacalda): el agua tapa el cuerpo (8 px) de quien ya venía de otra celda termal; ver scripts/overworld/sumersion_termal.gd
	# --- Buceo (MO08). Ver herramientas/generar_banderas_buceo.py ---
	BUCEO                = 35184372088832,	# 1 << 45 .		# Agua profunda buceable (MB_SEMI_DEEP_WATER / MB_UNUSED_DEEP_WATER / MB_SOOTOPOLIS_DEEP_WATER): en surf, A sumerge al mapa submarino
	NO_EMERGER           = 70368744177664,	# 1 << 46 .		# Bajo el agua no se puede emerger (MB_NO_SURFACING / MB_SEAWEED_NO_SURFACING)
	ALGA                 = 140737488355328,	# 1 << 47 .		# Algas submarinas (MB_SEAWEED / MB_SEAWEED_NO_SURFACING): encuentros con la tabla de agua
}
# ============================================================

## Máscara con las tres alturas de puente (PUENTE_BAJO | PUENTE_MEDIO | PUENTE_ALTO).
## Se pintan en la capa de datos elevada (layer_id >= 1) sobre las celdas del tablero.
const MASCARA_PUENTE: int = Flags.PUENTE_BAJO | Flags.PUENTE_MEDIO | Flags.PUENTE_ALTO

# Propiedades exportadas
@export var layer_id: int = 0    # Identificador único de esta capa de datos
@export var tile_size: int = 16  # Tamaño de tile en píxeles
@export var tile_data: Dictionary = {}  # Diccionario de datos: "x,y" -> {"flags": int}

# Variables internas
var selected_cell: Vector2 = Vector2(-1, -1)  # Celda seleccionada (para inspector)

func _ready() -> void:
	if not Engine.is_editor_hint():
		pass

## Avisos de banderas (ValidadorCapasAgua): PUENTE_* solo en capas >= 1 y dentro
## del mapa (VisibleOnScreenEnabler2D del padre), REFLEJO/AGUA_SALPICA ignorados
## en capas >= 1 y SURF + CAPA_SUPERIOR en la misma celda.
func _get_configuration_warnings() -> PackedStringArray:
	return ValidadorCapasAgua.validar_capa_datos(self, ValidadorCapasAgua.rect_celdas_de_mapa(get_parent()))

# ============================================================
# API de datos por celda (bajo nivel)
# ============================================================

## Devuelve el diccionario de datos de una celda ({"flags": int}).
func get_cell_data(cell: Vector2) -> Dictionary:
	var key = "%d,%d" % [cell.x, cell.y]
	return tile_data.get(key, {"flags": 0})

## Escribe el diccionario de datos de una celda.
func set_cell_data(cell: Vector2, data: Dictionary) -> void:
	if tile_data.is_read_only():
		tile_data = {}
	var key = "%d,%d" % [cell.x, cell.y]
	tile_data[key] = data
	notify_property_list_changed()
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()

# ============================================================
# API de banderas (alto nivel) — usa Flags enum para scripting
# ============================================================

## Devuelve la máscara de bits completa de una celda.
## Ejemplo:  var mask = mapa.get_flags(celda)
func get_flags(cell: Vector2) -> int:
	return get_cell_data(cell).get("flags", 0)

## Devuelve true si la celda tiene activas TODAS las banderas de la máscara.
## Ejemplo:  if mapa.has_flag(celda, TPTileDataMap.Flags.BLOQUEO):
func has_flag(cell: Vector2, flag_mask: int) -> bool:
	return (get_flags(cell) & flag_mask) == flag_mask

## Activa una o más banderas en una celda (OR).
## Ejemplo:  mapa.set_flag(celda, TPTileDataMap.Flags.SURF)
func set_flag(cell: Vector2, flag_mask: int) -> void:
	var data := get_cell_data(cell)
	data["flags"] = data.get("flags", 0) | flag_mask
	set_cell_data(cell, data)

## Desactiva una o más banderas en una celda (AND NOT).
## Ejemplo:  mapa.clear_flag(celda, TPTileDataMap.Flags.SURF)
func clear_flag(cell: Vector2, flag_mask: int) -> void:
	var data := get_cell_data(cell)
	data["flags"] = data.get("flags", 0) & ~flag_mask
	set_cell_data(cell, data)

## Altura del puente de la celda, como el "bridge type" del GBA:
## 0 = sin puente, 1 = PUENTE_BAJO, 2 = PUENTE_MEDIO, 3 = PUENTE_ALTO.
## Si hubiera varias pintadas gana la más alta.
func get_tipo_puente(cell: Vector2) -> int:
	var flags: int = get_flags(cell)
	if flags & Flags.PUENTE_ALTO:
		return 3
	if flags & Flags.PUENTE_MEDIO:
		return 2
	if flags & Flags.PUENTE_BAJO:
		return 1
	return 0

## true si en esta capa la celda está a ras de agua y admite sus efectos al
## pisarla (salpicadura de AGUA_SALPICA / AGUA_PIES, ondas circulares de
## AGUA_SALPICA). Las capas elevadas
## (layer_id >= 1: puentes) y las celdas con bandera de puente nunca los admiten.
func admite_efectos_agua(cell: Vector2) -> bool:
	return layer_id <= 0 and (get_flags(cell) & MASCARA_PUENTE) == 0

## Alterna una o más banderas en una celda (XOR).
## Ejemplo:  mapa.toggle_flag(celda, TPTileDataMap.Flags.BLOQUEO)
func toggle_flag(cell: Vector2, flag_mask: int) -> void:
	var data := get_cell_data(cell)
	data["flags"] = data.get("flags", 0) ^ flag_mask
	set_cell_data(cell, data)
