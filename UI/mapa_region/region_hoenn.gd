extends Control

enum ModoApertura { CARTEL, POKENAV, VUELO, POKEDEX }

const TAM_MAPA := Vector2(240, 160)
## CreateRegionMapCursor: (0x38,0x48) menos (8,8) para el cursor grande.
const CENTRO_ZOOM := Vector2(48, 64)
const MEDIO_CURSOR := Vector2(8, 8)
const DURACION_PASO_ZOOM := 8.0 / 60.0
const FACTOR_ZOOM := 2.0

## Marco de ventana elegido en OPCIONES → MARCO (`menu_box_N.png`). Igual que el
## resto de la UI: MenuBoxManager aplica la textura a cada NinePatchRect.
const MENU_BOX_MANAGER = preload("res://scripts/clases/MenuBoxManager.gd")
## Paneles de la pantalla cuyo borde es el marco de ventana del jugador.
const PANELES_CON_MARCO: PackedStringArray = ["detalles", "CuadroRegion"]

## Panel de texto del PokéNav (pokenav_before.c, sub_80EF9F8, casos 1 y 4): la
## sección en y = 4 * 8 y, debajo, hasta 4 landmarks (GetLandmarkName con
## i = 0..3), cada línea 2 tiles (16 px) más abajo.
const MAX_LANDMARKS_PANEL := 4
const SEPARACION_LINEAS_PANEL := 16.0
## `prioridad` a partir de la cual un POI es una sección del mapa (pueblo, ruta,
## ciudad...). Por debajo (2-3) son landmarks: bosques, cuevas, casas, etc.
const PRIORIDAD_SECCION := 4
## Banderas FLAG_LANDMARK_* (landmark.c): cuáles hay y qué mapa activa cada una.
const BANDERAS_LANDMARK = preload("res://scripts/mapas/banderas_landmark.gd")

## DEPURACIÓN: si está activada, el panel del PokéNav lista TODOS los landmarks de
## la casilla ignorando las banderas FLAG_LANDMARK_* (en el juego final debe estar
## desactivada: el original solo muestra los landmarks que el jugador ya conoce).
## Al abrir la pantalla se deja constancia en el log (y un aviso si está activada).
@export var debug_mostrar_todos_los_landmarks: bool = false

@export var tile_size: int = 8
@export var cursor_step: int = 8 # el cursor se mueve en incrementos de 8 px
@export var cursor_node_path: NodePath
@export var cursor_center_offset: Vector2 = Vector2(-4, -4) # ajuste visual para centrar iconos
@export var min_tile_x: int = 0
@export var max_tile_x: int = 27
@export var min_tile_y: int = 0
@export var max_tile_y: int = 14
@export var repeat_initial_delay: float = 0.25
@export var repeat_interval: float = 0.08
@export var tween_duration: float = 0.5
@export var cursor_speed_pixels: float = 200.0 # pixels per second for constant speed
@export var min_tween_duration: float = 0.02
@export var free_move_mode: bool = true
@export var free_move_speed_pixels: float = 120.0
@export var label_nombre_path: NodePath

# Señal para notificar que el mapa de región debe cerrarse
signal mapa_cerrado
## Modo VUELO: se eligió un destino volable. `destino` = {mapa: String,
## celda: Vector2 (tiles locales del mapa, ya resuelta según el sexo), nombre: String}.
signal destino_vuelo_elegido(destino: Dictionary)

var modo_apertura: ModoApertura = ModoApertura.CARTEL

var cursor_node: Node = null
var label_nombre: Node = null
var _prev_dir: Vector2i = Vector2i.ZERO
var _hold_timer: float = 0.0
var _repeat_elapsed: float = 0.0
var _is_moving: bool = false
var _is_free_moving: bool = false
var _free_snap_direction: Vector2i = Vector2i.ZERO
var _zoom_activo: bool = false
var _cierre_solicitado: bool = false
var _input_habilitado: bool = false

# Interpolación manual
var _move_start_pos: Vector2 = Vector2.ZERO
var _move_target_pos: Vector2 = Vector2.ZERO
var _move_progress: float = 0.0
var _move_duration: float = 0.05

# POI = array de diccionarios con al menos las claves: id, map_id, tile: [x,y], tipo, nombre, icono, encounter_table_id (opcional)
var poi_list: Array = []
var poi_lookup: Dictionary = {} # "x_y" -> Array of poi indices

# Encuentros: id -> dict de tabla de encuentros
var encounter_tables: Dictionary = {}

# Posición del jugador en tiles
var player_tile: Vector2i = Vector2i.ZERO

## Líneas del panel para la casilla seleccionada: la sección y sus landmarks.
## En el mapa completo del PokéNav solo se muestra la primera (cabecera).
var _nombres_panel: PackedStringArray = PackedStringArray()

func _ready() -> void:
	if cursor_node_path and has_node(cursor_node_path):
		cursor_node = get_node(cursor_node_path)
	else:
		cursor_node = null

	# Label para mostrar el nombre del POI (ej. detalles/nombre)
	if label_nombre_path and has_node(label_nombre_path):
		label_nombre = get_node(label_nombre_path)
	else:
		label_nombre = null
	_preparar_etiqueta_panel()
	_recordar_estado_debug_landmarks()

	_aplicar_modo_apertura()

	# Intentar cargar metadata regional centralizada
	var meta_path = "res://BaseDatos/region_map_metadata.json"
	_logear("Intentando cargar metadata regional: %s" % meta_path)
	var loaded_region = false
	if poi_list.size() == 0:
		loaded_region = load_region_metadata("hoenn_poi")
		if not loaded_region:
			return

	# El marcador y el cursor comienzan en el POI del mapa actual. En interiores
	# se usa mapa_exterior_asociado (por ejemplo, el centro de Pueblo Escaso).
	var tile_inicial := _configurar_posicion_jugador()
	if cursor_node:
		move_cursor_to_tile(tile_inicial)
		_start_cursor_animation()

	# El punto de entrada habilita el input después de terminar su transición.
	set_process_input(_input_habilitado)

## Recordatorio en el log, SIEMPRE, de si `debug_mostrar_todos_los_landmarks` está
## activa. Cuando lo está, además un `push_warning` para que destaque en el
## depurador: es una ayuda de desarrollo que no debe llegar al juego final.
func _recordar_estado_debug_landmarks() -> void:
	if debug_mostrar_todos_los_landmarks:
		var aviso := "debug_mostrar_todos_los_landmarks = ACTIVADA (se ignoran las banderas de landmarks)"
		_logear(aviso)
		push_warning("[MAPA REGION] %s" % aviso)
	else:
		_logear("debug_mostrar_todos_los_landmarks = DESACTIVADA (se respetan banderas FLAG_LANDMARK_*)")

## Debe llamarse antes de agregar la instancia al árbol cuando viene de un cartel.
func configurar_como_cartel() -> void:
	_configurar_modo(ModoApertura.CARTEL)

## Debe llamarse antes de agregar la instancia al árbol cuando viene del PokéNav.
func configurar_como_pokenav() -> void:
	_configurar_modo(ModoApertura.POKENAV)

## Debe llamarse antes de agregar la instancia al árbol cuando se usa VUELO:
## A sobre un POI volable emite `destino_vuelo_elegido`.
func configurar_como_vuelo() -> void:
	_configurar_modo(ModoApertura.VUELO)

## Pantalla ÁREA de la POKéDEX: solo el mapa y el icono del jugador, sin
## cursor, cuadros de texto, movimiento ni controles (la POKéDEX los gestiona).
func configurar_como_pokedex() -> void:
	_configurar_modo(ModoApertura.POKEDEX)

func habilitar_input() -> void:
	_input_habilitado = true
	set_process_input(true)

func _configurar_modo(nuevo_modo: ModoApertura) -> void:
	modo_apertura = nuevo_modo
	if is_node_ready():
		_aplicar_modo_apertura()

## VUELO comparte la presentación del cartel (sin marco del PokéNav ni zoom).
func _aplicar_modo_apertura() -> void:
	var desde_pokenav := modo_apertura == ModoApertura.POKENAV
	var en_pokedex := modo_apertura == ModoApertura.POKEDEX
	var pokenav_buttom := get_node_or_null("PokenavButtom") as CanvasItem
	var barra_titulo := get_node_or_null("BarraTitulo") as CanvasItem
	var cuadro_region := get_node_or_null("CuadroRegion") as CanvasItem
	var detalles := get_node_or_null("detalles") as Control
	_aplicar_marco()
	if pokenav_buttom:
		pokenav_buttom.visible = desde_pokenav
	if barra_titulo:
		barra_titulo.visible = desde_pokenav
	if cuadro_region:
		cuadro_region.visible = not desde_pokenav and not en_pokedex
	if detalles:
		detalles.visible = not en_pokedex
		if not desde_pokenav:
			detalles.position = Vector2(128, 128)
			detalles.size = Vector2(112, 32)
			(get_node("detalles/nombre") as Label).size.x = 96
	if not desde_pokenav:
		_zoom_activo = false
	_aplicar_zoom()
	# El cursor se mueve en _process leyendo Input directamente.
	var cursor := get_node_or_null(cursor_node_path) as CanvasItem if cursor_node_path else null
	if cursor:
		cursor.visible = not en_pokedex
	set_process(not en_pokedex)

## Tipo de marco de ventana de las opciones de la partida (1 si no hay datos).
func _tipo_marco_elegido() -> int:
	var tipo := 1
	if SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		tipo = int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	return tipo

## En el original las ventanas del mapa de región usan el marco elegido en
## OPCIONES. Las texturas `menu_box_N.png` tienen la misma geometría (24x24, 8 px
## de borde), así que se conservan `patch_margin_*` y `axis_stretch_*` de la escena.
func _aplicar_marco() -> void:
	var tipo := _tipo_marco_elegido()
	for nombre_panel in PANELES_CON_MARCO:
		var panel := get_node_or_null(nombre_panel) as NinePatchRect
		if panel:
			MENU_BOX_MANAGER.apply_texture_to_ninepatch(panel, tipo)

## Separación entre líneas del panel: 16 px como el original (2 tiles). Se usa
## una copia local del LabelSettings para no tocar el recurso compartido.
func _preparar_etiqueta_panel() -> void:
	var etiqueta := label_nombre as Label
	if etiqueta == null or etiqueta.label_settings == null:
		return
	var ajustes := etiqueta.label_settings.duplicate() as LabelSettings
	var altura_fuente := 0.0
	if ajustes.font:
		altura_fuente = ajustes.font.get_height(ajustes.font_size)
	ajustes.line_spacing = SEPARACION_LINEAS_PANEL - altura_fuente
	etiqueta.label_settings = ajustes

### Helpers para posición que soportan Node2D y Control
func _get_node_pos(n: Node) -> Vector2:
	return (n as Node2D).position

func _set_node_pos(n: Node, p: Vector2) -> void:
	(n as Node2D).position = p

### Input handling para mover cursor con las acciones del proyecto (btn_arriba, btn_abajo, btn_izquierda, btn_derecha)
func _input(event: InputEvent) -> void:
	if not _input_habilitado or _cierre_solicitado:
		return
	if event.is_action_pressed("btn_cancelar"):
		_cierre_solicitado = true
		mapa_cerrado.emit()
		get_viewport().set_input_as_handled()
	elif modo_apertura == ModoApertura.POKENAV and event.is_action_pressed("btn_accion"):
		# No arrastrar un desplazamiento libre/interpolado al cambiar de vista.
		_is_moving = false
		_is_free_moving = false
		move_cursor_to_tile(cursor_position_to_tile(_get_node_pos(cursor_node) - cursor_center_offset))
		_zoom_activo = not _zoom_activo
		_aplicar_zoom()
		get_viewport().set_input_as_handled()
	elif modo_apertura == ModoApertura.VUELO and event.is_action_pressed("btn_accion"):
		var poi := _poi_volable_bajo_cursor()
		if poi.is_empty():
			return
		_cierre_solicitado = true
		get_viewport().set_input_as_handled()
		var sexo := str(_obtener_contexto_jugador().get("sexo", "M"))
		destino_vuelo_elegido.emit(_resolver_destino_vuelo(poi, sexo, _tile_cursor()))

## Primer POI bajo el cursor con `vuelo` y `vuelo_destino`; {} si no hay.
func _poi_volable_bajo_cursor() -> Dictionary:
	if not cursor_node:
		return {}
	return _poi_volable_en_tile(_tile_cursor())

func _tile_cursor() -> Vector2i:
	return _clamp_tile(cursor_position_to_tile(_get_node_pos(cursor_node) - cursor_center_offset))

## Como en pokeruby (sub_80FB758), un pueblo/ciudad solo es volable si ya se
## visitó (SistemaGuardado.lugar_visitado, bandera FLAG_VISITED_*).
func _poi_volable_en_tile(tile: Vector2i) -> Dictionary:
	for poi in get_poi_data_at_tile(tile):
		if bool(poi.get("vuelo", false)) and poi.get("vuelo_destino") is Dictionary \
				and _destino_visitado(poi):
			return poi
	return {}

func _destino_visitado(poi: Dictionary) -> bool:
	return SistemaGuardado.lugar_visitado(str(poi["vuelo_destino"].get("mapa", "")))

## Parte de una sección en varias partes bajo `tile` ({tile, nombre, vuelo_destino}), o {} si el POI no
## tiene `vuelo_zonas` o falta su bandera. Como sMultiPartMapSections de pokeruby (region_map.c): en
## COLOSALIA, con FLAG_SYS_POKEMON_LEAGUE_FLY (se pone al entrar en el vestíbulo de la LIGA), la casilla de
## arriba es la LIGA POKéMON (HEAL_LOCATION_EVER_GRANDE_CITY_POKEMON_LEAGUE) y la de abajo el CENTRO POKéMON;
## sin ella las dos van al CENTRO POKéMON y el panel solo dice el nombre de la ciudad.
func _zona_vuelo(poi: Dictionary, tile: Vector2i) -> Dictionary:
	if not poi.get("vuelo_zonas") is Array:
		return {}
	var bandera := str(poi.get("vuelo_zonas_bandera", ""))
	if not bandera.is_empty() and not SistemaGuardado.get_flag(bandera):
		return {}
	for zona in poi["vuelo_zonas"]:
		if zona is Dictionary and zona.get("tile") is Array and Vector2i(int(zona["tile"][0]), int(zona["tile"][1])) == tile:
			return zona
	return {}

## Convierte `vuelo_destino` del POI (o el de su zona bajo `tile`, ver _zona_vuelo) al diccionario de la
## señal. La chica usa cx_f/cy_f cuando existen (Villa Raíz: cada sexo aterriza frente a su casa).
func _resolver_destino_vuelo(poi: Dictionary, sexo: String, tile: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var zona := _zona_vuelo(poi, tile)
	var datos: Dictionary = zona["vuelo_destino"] if zona.get("vuelo_destino") is Dictionary else poi["vuelo_destino"]
	var celda := Vector2(float(datos.get("cx", 0)), float(datos.get("cy", 0)))
	if sexo.to_upper() == "F" and datos.has("cx_f") and datos.has("cy_f"):
		celda = Vector2(float(datos["cx_f"]), float(datos["cy_f"]))
	return {
		"mapa": str(datos.get("mapa", "")),
		"celda": celda,
		"nombre": str(poi.get("nombre", "")),
	}

func _on_cursor_move(dx: int, dy: int) -> void:
	# ahora delegamos en _request_move
	_request_move(Vector2i(dx, dy))

func _process(delta: float) -> void:
	if _cierre_solicitado or not cursor_node:
		return

	# Completa suavemente el movimiento hasta una posición de la grilla. Se
	# procesa antes del modo libre para que el ajuste iniciado al soltar no quede
	# bloqueado por la rama free_move_mode.
	if _is_moving:
		_move_progress += delta / max(_move_duration, 0.0001)
		var t: float = clampf(_move_progress, 0.0, 1.0)
		_set_node_pos(cursor_node, _move_start_pos.lerp(_move_target_pos, t))
		update_cursor_visual()
		_actualizar_centro_zoom()
		if t >= 1.0:
			_is_moving = false
			_set_node_pos(cursor_node, _move_target_pos)
			update_cursor_visual()
			_actualizar_centro_zoom()
		return

	# En detalle se desplaza el mapa una casilla en 8 frames (region_map.c),
	# también en diagonal. El cursor lógico cambia, pero su centro visual no.
	if _zoom_activo:
		var direccion_zoom := Vector2i(
			(1 if Input.is_action_pressed("btn_derecha") else 0) - (1 if Input.is_action_pressed("btn_izquierda") else 0),
			(1 if Input.is_action_pressed("btn_abajo") else 0) - (1 if Input.is_action_pressed("btn_arriba") else 0)
		)
		if direccion_zoom != Vector2i.ZERO:
			_request_move(direccion_zoom)
		return

	# Modo de movimiento libre por pixeles (ignora la cuadricula mientras se mueve)
	if free_move_mode:
		var fdx = (1 if Input.is_action_pressed("btn_derecha") else 0) - (1 if Input.is_action_pressed("btn_izquierda") else 0)
		var fdy = (1 if Input.is_action_pressed("btn_abajo") else 0) - (1 if Input.is_action_pressed("btn_arriba") else 0)
		var dirf = Vector2(fdx, fdy)
		if dirf != Vector2.ZERO:
			if not _is_free_moving:
				_free_snap_direction = Vector2i.ZERO
			# Conservar la última dirección de cada eje. Es importante si el usuario
			# deja de pulsar un eje antes que el otro durante un movimiento diagonal.
			if fdx != 0:
				_free_snap_direction.x = fdx
			if fdy != 0:
				_free_snap_direction.y = fdy
			# mover pixel a pixel; permitir cambio de direccion en vuelo
			var dir_norm = dirf.normalized() if dirf.length() > 0 else Vector2.ZERO
			var pos = _get_node_pos(cursor_node) + dir_norm * free_move_speed_pixels * delta
			# limitar pantalla según límites en tiles convertidos a píxeles
			var min_px = min_tile_x * tile_size
			var max_px = (max_tile_x) * tile_size
			var min_py = min_tile_y * tile_size
			var max_py = (max_tile_y) * tile_size
			pos.x = clamp(pos.x, min_px + cursor_center_offset.x, max_px + cursor_center_offset.x)
			pos.y = clamp(pos.y, min_py + cursor_center_offset.y, max_py + cursor_center_offset.y)
			_set_node_pos(cursor_node, pos)
			# actualizar label/POI en cada desplazamiento
			update_cursor_visual()
			_actualizar_centro_zoom()
			_is_free_moving = true
			return
		else:
			# Al soltar, terminar en la siguiente celda en el mismo sentido del
			# movimiento. Nunca redondear hacia el tile de origen.
			if _is_free_moving:
				_is_free_moving = false
				_iniciar_ajuste_a_grilla(_free_snap_direction)
			return

	# detectar direcciones combinadas para permitir diagonal (modo tile)
	var dx = (1 if Input.is_action_pressed("btn_derecha") else 0) - (1 if Input.is_action_pressed("btn_izquierda") else 0)
	var dy = (1 if Input.is_action_pressed("btn_abajo") else 0) - (1 if Input.is_action_pressed("btn_arriba") else 0)
	var dir = Vector2i(dx, dy)
	if dir != Vector2i.ZERO and not _is_moving:
		if dir != _prev_dir:
			# nueva dirección -> movimiento inmediato
			_request_move(dir)
			_hold_timer = 0.0
			_repeat_elapsed = 0.0
		else:
			_hold_timer += delta
			if _hold_timer >= repeat_initial_delay:
				_repeat_elapsed += delta
				if _repeat_elapsed >= repeat_interval:
					_request_move(dir)
					_repeat_elapsed = 0.0
	else:
		_hold_timer = 0.0
		_repeat_elapsed = 0.0
	_prev_dir = dir

## Completa el desplazamiento libre hasta la grilla de 8×8 respetando el último
## sentido de cada eje. Un toque breve siempre avanza una celda; mantener pulsado
## conserva el movimiento continuo y solo ajusta la fracción restante al soltar.
func _iniciar_ajuste_a_grilla(direccion: Vector2i) -> void:
	var posicion_actual := _get_node_pos(cursor_node)
	var tile_destino := _calcular_tile_snap_direccional(posicion_actual, direccion)
	var destino := Vector2(tile_destino * tile_size) + cursor_center_offset
	if posicion_actual.is_equal_approx(destino):
		_set_node_pos(cursor_node, destino)
		update_cursor_visual()
		_actualizar_centro_zoom()
		return
	_move_start_pos = posicion_actual
	_move_target_pos = destino
	_move_progress = 0.0
	_move_duration = max(
		min_tween_duration,
		posicion_actual.distance_to(destino) / max(free_move_speed_pixels, 1.0)
	)
	_is_moving = true

func _calcular_tile_snap_direccional(posicion: Vector2, direccion: Vector2i) -> Vector2i:
	var coordenada := (posicion - cursor_center_offset) / float(tile_size)
	var destino := Vector2i(
		_snap_eje_direccional(coordenada.x, direccion.x),
		_snap_eje_direccional(coordenada.y, direccion.y)
	)
	return _clamp_tile(destino)

func _snap_eje_direccional(valor: float, direccion: int) -> int:
	var entero_cercano := roundi(valor)
	if is_equal_approx(valor, float(entero_cercano)):
		return entero_cercano
	if direccion < 0:
		return floori(valor)
	if direccion > 0:
		return ceili(valor)
	# Este eje no se movió o ya dejó de pulsarse antes que el otro. En ese caso
	# se usa el punto más cercano; para los ejes movidos siempre hay dirección.
	return entero_cercano

### API de carga y datos
## Carga una lista de POI (Array de Dictionary) en memoria y reconstruye el índice interno.
## Los POI deben contener al menos la clave `tile` con [x,y].
func load_pois(pois: Array) -> void:
	"""Carga una lista de POI (lista de Diccionarios) y reconstruye el índice."""
	poi_list = pois.duplicate()
	_build_poi_lookup()

## Reconstruye el índice `poi_lookup` para búsqueda rápida por tile (clave "x_y").
## Llama internamente a esta función tras cargar o modificar `poi_list`.
func _build_poi_lookup() -> void:
	poi_lookup.clear()
	for i in range(poi_list.size()):
		var p = poi_list[i]
		if not p.has("tile"):
			continue
		var t = p.tile
		var size = p.tile_size if p.has("tile_size") and typeof(p.tile_size) == TYPE_ARRAY and p.tile_size.size() >= 2 else [1, 1]
		for dx in range(size[0]):
			for dy in range(size[1]):
				var cell = Vector2i(t[0] + dx, t[1] + dy)
				var key = _tile_key(cell)
				if not poi_lookup.has(key):
					poi_lookup[key] = []
				poi_lookup[key].append(i)

### Cursor y selección
func _tile_key(tile: Vector2i) -> String:
	return "%d_%d" % [tile.x, tile.y]

func cursor_position_to_tile(pos: Vector2) -> Vector2i:
	# Convención: tile = floor(pos / tile_size)
	return Vector2i((pos / tile_size).floor())

func move_cursor_delta(dx: int, dy: int) -> void:
	_request_move(Vector2i(dx, dy))

func move_cursor_to_tile(tile: Vector2i) -> void:
	if not cursor_node:
		return
	var tile_clamped = _clamp_tile(tile)
	var pos = Vector2(tile_clamped.x * tile_size, tile_clamped.y * tile_size) + cursor_center_offset
	_set_node_pos(cursor_node, pos)
	update_cursor_visual()
	_actualizar_centro_zoom()

func _request_move(dir: Vector2i) -> void:
	if not cursor_node:
		return
	# calcular tile actual y destino
	var cur_tile = cursor_position_to_tile(_get_node_pos(cursor_node) - cursor_center_offset)
	var dest_tile = cur_tile + dir
	dest_tile = _clamp_tile(dest_tile)
	if dest_tile == cur_tile:
		return
	_move_start_pos = _get_node_pos(cursor_node)
	_move_target_pos = Vector2(dest_tile.x * tile_size, dest_tile.y * tile_size) + cursor_center_offset
	var dist = _move_start_pos.distance_to(_move_target_pos)
	_move_duration = max(min_tween_duration, dist / max(cursor_speed_pixels, 1.0))
	if _zoom_activo:
		_move_duration = DURACION_PASO_ZOOM
	_move_progress = 0.0
	_is_moving = true

# removed tween callback functions (we now use manual interpolation)

## Actualiza la visualización relacionada con el cursor: busca POI en la tile actual
## y emite `poi_selected` para que la UI actualice el tooltip/label correspondiente.
func update_cursor_visual() -> void:
	# Actualizar información visible y selección al mover el cursor
	if not cursor_node:
		return
	var tile = cursor_position_to_tile(_get_node_pos(cursor_node) - cursor_center_offset)
	var tile_clamped = _clamp_tile(tile)
	var pois = get_poi_at_tile(tile_clamped)
	# Si hay POI, podríamos cambiar el sprite del cursor o mostrar tooltip (UI externa)
	# Emitir señal para que la UI maneje la visualización
	# En VUELO solo se nombra un destino volable ya visitado (aunque comparta
	# tile con una ruta); rutas y pueblos sin visitar dejan el nombre en blanco,
	# como PrintFlyTargetName de pokeruby (ewramBlankMapName).
	if modo_apertura == ModoApertura.VUELO:
		var poi_vuelo := _poi_volable_en_tile(tile_clamped)
		var zona := _zona_vuelo(poi_vuelo, tile_clamped)
		if not zona.is_empty():
			# Sección y parte en dos líneas (MenuPrint_RightAligned de partNames).
			if label_nombre:
				label_nombre.text = "%s\n%s" % [poi_vuelo.nombre, zona.get("nombre", "")]
				if label_nombre is Control:
					(label_nombre as Control).size.y = 0.0
		elif not poi_vuelo.is_empty():
			_on_poi_selected(poi_vuelo)
		elif label_nombre:
			label_nombre.text = ""
	elif modo_apertura == ModoApertura.POKENAV:
		# Sección + landmarks de la casilla, como sub_80EF9F8 de pokenav_before.c.
		_nombres_panel = obtener_nombres_casilla(tile_clamped)
		_refrescar_texto_panel()
	elif pois and pois.size() > 0:
		# Cartel: solo el nombre de la sección (el POI de mayor prioridad).
		_on_poi_selected(get_poi_principal_en_tile(tile_clamped))
	else:
		# limpiar label cuando no hay POI
		if label_nombre:
			label_nombre.text = ""

func _aplicar_zoom() -> void:
	var contenedor := get_node_or_null("zoom") as Node2D
	if not contenedor:
		return
	contenedor.scale = Vector2.ONE * (FACTOR_ZOOM if _zoom_activo else 1.0)
	var titulo := get_node_or_null("BarraTitulo/vista") as Label
	if titulo:
		titulo.text = "VISTA DETALLADA" if _zoom_activo else "VISTA COMPLETA"
	var boton_zoom := get_node_or_null("PokenavButtom/btn_accion") as Label
	if boton_zoom:
		boton_zoom.text = "COMPL." if _zoom_activo else "PARC."
	if modo_apertura == ModoApertura.POKENAV:
		# pokenav.c: marco (13,3)-(29,17), texto (112,32).
		# En vista completa BG0VOFS=160 desplaza el borde superior a y=120.
		# Solo se ve su cabecera, recortada por la barra de controles en y=144.
		var detalles := get_node("detalles") as Control
		detalles.position = Vector2(104, 24 if _zoom_activo else 120)
		detalles.size = Vector2(136, 120)
		var nombre := get_node("detalles/nombre") as Label
		nombre.size.x = 120
		_refrescar_texto_panel()
	_actualizar_centro_zoom()

func _actualizar_centro_zoom() -> void:
	if not _zoom_activo or not cursor_node:
		var contenedor_sin_zoom := get_node_or_null("zoom") as Node2D
		if contenedor_sin_zoom:
			contenedor_sin_zoom.position = Vector2.ZERO
		return
	var contenedor := get_node_or_null("zoom") as Node2D
	if not contenedor:
		return
	# No limitar el encuadre al rectángulo de la textura: decomp limita la
	# selección/scroll, incluso en los extremos, sin desplazar el cursor fijo.
	contenedor.position = CENTRO_ZOOM - (_get_node_pos(cursor_node) + MEDIO_CURSOR) * FACTOR_ZOOM

## Handler local para la señal `poi_selected` que escribe el nombre del POI
## en el `label_nombre` (soporta `set_text()` o propiedad `text`).
func _on_poi_selected(poi: Dictionary) -> void:
	if not label_nombre:
		return
	label_nombre.text = str(poi.nombre)

## Escribe en el panel las líneas de `_nombres_panel`. En el mapa completo (BG0VOFS
## = 160) el original solo deja ver la cabecera del panel, es decir, la primera
## línea; en la vista detallada se ve la sección y todos sus landmarks.
func _refrescar_texto_panel() -> void:
	if not label_nombre:
		return
	var visibles := _nombres_panel
	if not _zoom_activo and visibles.size() > 1:
		visibles = visibles.slice(0, 1)
	var texto := "\n".join(visibles)
	if label_nombre.text == texto:
		return
	label_nombre.text = texto
	# La etiqueta crece con las líneas pero no se encoge sola.
	if label_nombre is Control:
		(label_nombre as Control).size.y = 0.0

## Índice en `poi_list` del POI de mayor `prioridad` que cubre la casilla; a
## igualdad, el primero en el JSON. -1 si no hay ninguno.
func _indice_poi_principal(tile: Vector2i) -> int:
	var elegido := -1
	var mejor := 0
	for indice in get_poi_at_tile(tile):
		var prioridad := int(poi_list[indice].get("prioridad", 0))
		if elegido == -1 or prioridad > mejor:
			elegido = indice
			mejor = prioridad
	return elegido

## POI que da nombre a la casilla (la sección). {} si la casilla está vacía.
func get_poi_principal_en_tile(tile: Vector2i) -> Dictionary:
	var indice := _indice_poi_principal(tile)
	if indice < 0:
		return {}
	return poi_list[indice]

## Un POI es un landmark (bosque, cueva, casa...) si su prioridad es menor que
## la de una sección, o si no tiene mapa propio (`map_id` vacío: etiquetas como la
## CORRIENTE OCEÁNICA, que cubre varias rutas pero no es una de ellas).
static func _es_landmark(poi: Dictionary) -> bool:
	if int(poi.get("prioridad", 0)) < PRIORIDAD_SECCION:
		return true
	return str(poi.get("map_id", poi.get("id", ""))).strip_edges().is_empty()

## Líneas del panel de la casilla (sub_80EF9F8): el nombre de la sección y,
## debajo, hasta `max_landmarks` nombres de landmarks (GetLandmarkName con
## i = 0..3 mientras no devuelva NULL).
##
## - La sección es el POI de mayor prioridad (a igualdad, el primero del JSON).
##   Así ARRECÍPOLIS (6) se nombra aunque la caja de RUTA 126 (4) la cubra, y
##   esa ruta no se lista como landmark de la ciudad.
## - Los landmarks salen en el orden del JSON, NO por prioridad: landmark.c fija
##   un orden por casilla (p. ej. CÁMARA SELLADA antes que CORRIENTE OCEÁNICA en
##   la última casilla de la RUTA 134, aunque la corriente tenga prioridad 4) y
##   el JSON se ordena para reproducirlo.
## - Nombres repetidos (CASCADA METEORO en dos POI) se listan una vez.
## - Como GetLandmarkName, un landmark con `bandera` (FLAG_LANDMARK_*) solo se
##   lista si esa bandera está activada (p. ej. CASA del SR. ARENQUE hasta
##   conocerla), salvo con `debug_mostrar_todos_los_landmarks`. La sección y los
##   landmarks sin bandera no dependen de ellas.
func obtener_nombres_casilla(tile: Vector2i, max_landmarks: int = MAX_LANDMARKS_PANEL) -> PackedStringArray:
	var nombres := PackedStringArray()
	var principal := _indice_poi_principal(tile)
	if principal < 0:
		return nombres
	nombres.append(str(poi_list[principal].get("nombre", "")))
	for indice in get_poi_at_tile(tile):
		if nombres.size() > max_landmarks:
			break
		if indice == principal:
			continue
		var poi: Dictionary = poi_list[indice]
		if not _es_landmark(poi) or not _landmark_visible(poi):
			continue
		var nombre := str(poi.get("nombre", ""))
		if nombre.is_empty() or nombres.has(nombre):
			continue
		nombres.append(nombre)
	return nombres

## ¿Se lista este landmark en el panel? Sí si no tiene `bandera`, si la bandera
## está activada en la partida o si la depuración muestra todos.
func _landmark_visible(poi: Dictionary) -> bool:
	if debug_mostrar_todos_los_landmarks:
		return true
	var bandera := str(poi.get("bandera", "")).strip_edges()
	return bandera.is_empty() or BANDERAS_LANDMARK.esta_activa(bandera)

## Devuelve la lista de índices de POI (en `poi_list`) que están en la tile dada.
## Útil para localizar rápidamente qué POI existen en una coordenada concreta.
func get_poi_at_tile(tile: Vector2i) -> Array:
	var key = _tile_key(tile)
	if poi_lookup.has(key):
		return poi_lookup[key]
	return []

## Devuelve un Array con los diccionarios de POI situados en la tile indicada.
## Construye la respuesta a partir de los índices obtenidos por `get_poi_at_tile`.
func get_poi_data_at_tile(tile: Vector2i) -> Array:
	var idxs = get_poi_at_tile(tile)
	var out = []
	for i in idxs:
		out.append(poi_list[i])
	return out

## Selecciona (emite `poi_selected`) el POI principal (mayor prioridad) bajo el cursor actual.
## No realiza acciones adicionales; la UI o el controlador superior reaccionará a la señal.
func select_poi_under_cursor() -> void:
	if not cursor_node:
		return
	var tile = cursor_position_to_tile(_get_node_pos(cursor_node) - cursor_center_offset)
	var tile_clamped = _clamp_tile(tile)
	var principal := get_poi_principal_en_tile(tile_clamped)
	if not principal.is_empty():
		_on_poi_selected(principal)

func _clamp_tile(tile: Vector2i) -> Vector2i:
	var x = clamp(tile.x, min_tile_x, max_tile_x)
	var y = clamp(tile.y, min_tile_y, max_tile_y)
	return Vector2i(x, y)

### Jugador y marcador
func _configurar_posicion_jugador() -> Vector2i:
	var contexto := _obtener_contexto_jugador()
	var mapa_id := str(contexto.get("mapa_id", ""))
	var sexo := str(contexto.get("sexo", "M")).to_upper()
	var poi_jugador := _buscar_poi_por_mapa(mapa_id)
	var tile := Vector2i.ZERO
	var casilla_fija: Vector2i = contexto.get("casilla_fija", Vector2i(-1, -1))
	if not poi_jugador.is_empty() and casilla_fija.x >= 0 and casilla_fija.y >= 0:
		tile = casilla_fija
	elif not poi_jugador.is_empty():
		# Como InitializeCursorPosition: la casilla depende de dónde está el
		# jugador dentro de la sección. Sin celda o tamaño conocidos devuelve
		# la casilla superior izquierda del POI.
		tile = calcular_tile_en_poi(
			poi_jugador,
			contexto.get("celda", Vector2i.ZERO),
			contexto.get("tam_mapa", Vector2i.ZERO)
		)
	elif not poi_list.is_empty():
		var primer_tile: Array = poi_list[0].get("tile", [0, 0])
		tile = Vector2i(int(primer_tile[0]), int(primer_tile[1]))
		push_warning("[MAPA REGION] No hay POI para el mapa actual '%s'; se usa el primer POI." % mapa_id)

	player_tile = tile
	var chico := get_node_or_null("zoom/chico") as AnimatedSprite2D
	var chica := get_node_or_null("zoom/chica") as AnimatedSprite2D
	if chico:
		chico.visible = not poi_jugador.is_empty() and sexo != "F"
		chico.position = Vector2(tile * tile_size) + cursor_center_offset
	if chica:
		chica.visible = not poi_jugador.is_empty() and sexo == "F"
		chica.position = Vector2(tile * tile_size) + cursor_center_offset
	return tile

## Casilla del jugador dentro de su sección (InitializeCursorPosition, region_map.c).
## `celda` es su posición local en el mapa exterior y `tam_mapa` el tamaño de ese
## mapa en celdas; la casilla es `poi.tile` más `celda` escalada al tamaño
## (`tile_size`) de la sección. División entera, como en el original.
static func calcular_tile_en_poi(poi: Dictionary, celda: Vector2i, tam_mapa: Vector2i) -> Vector2i:
	var datos_tile: Array = poi.get("tile", [0, 0])
	var origen := Vector2i(int(datos_tile[0]), int(datos_tile[1]))
	if tam_mapa.x <= 0 or tam_mapa.y <= 0:
		return origen
	var datos_tam: Array = poi.get("tile_size", [1, 1])
	var ancho_seccion := 1
	var alto_seccion := 1
	if datos_tam.size() >= 2:
		ancho_seccion = maxi(1, int(datos_tam[0]))
		alto_seccion = maxi(1, int(datos_tam[1]))
	var x := maxi(0, celda.x)
	var y := maxi(0, celda.y)
	# r1 == 0 → 1; el resultado se acota a la última casilla de la sección.
	@warning_ignore("integer_division")
	var razon_x := maxi(1, tam_mapa.x / ancho_seccion)
	@warning_ignore("integer_division")
	var razon_y := maxi(1, tam_mapa.y / alto_seccion)
	@warning_ignore("integer_division")
	var cx := mini(x / razon_x, ancho_seccion - 1)
	@warning_ignore("integer_division")
	var cy := mini(y / razon_y, alto_seccion - 1)
	# Rutas largas que el original reparte por umbrales fijos de celda.
	# (RUTA 114 hace `if y != 0: x = 0`, irrelevante con una sección de 1x3.)
	var clave := str(poi.get("map_id", poi.get("id", ""))).to_lower()
	if clave == "ruta_121":
		cx = 0
		if x > 14:
			cx = 1
		if x > 28:
			cx += 1
		if x > 54:
			cx += 1
	elif clave == "ruta_126":
		cx = 0
		if x > 32:
			cx = 1
		if x > 51:
			cx += 1
		cy = 0
		if y > 37:
			cy = 1
		if y > 56:
			cy += 1
	return origen + Vector2i(cx, cy)

## Compara claves de mapa ignorando mayúsculas y separadores ("CIUDAD_FERRICA"
## de mapa_exterior_asociado vs. "ciudad_ferrica" del nombre de escena).
static func _misma_clave_mapa(a: String, b: String) -> bool:
	var clave_a := a.strip_edges().to_lower().replace("_", "").replace("-", "").replace(" ", "")
	var clave_b := b.strip_edges().to_lower().replace("_", "").replace("-", "").replace(" ", "")
	return not clave_a.is_empty() and clave_a == clave_b

## Devuelve {mapa_id, sexo, celda, tam_mapa, casilla_fija}. `celda` es la posición
## local en el mapa exterior y `tam_mapa` su tamaño en celdas; (0, 0) si no se
## conocen, en cuyo caso el icono cae en la casilla superior izquierda de la
## sección. `casilla_fija` es `MapaConfiguracion.casilla_mapa_region` ((-1, -1): no hay).
func _obtener_contexto_jugador() -> Dictionary:
	var mapa_id := ""
	var celda := Vector2i.ZERO
	var tam_mapa := Vector2i.ZERO
	var casilla_fija := Vector2i(-1, -1)
	var admin := get_node_or_null("/root/AdministradorMapa")
	if admin:
		mapa_id = str(admin.get("mapa_actual_key"))
		var mapa_actual = admin.get("mapa_actual")
		if mapa_actual is MapaConfiguracion:
			if mapa_actual.esInterior:
				if not mapa_actual.mapa_exterior_asociado.is_empty():
					mapa_id = mapa_actual.mapa_exterior_asociado
					# Equivalente al warp4 del original: la celda exterior desde la
					# que se entró al interior, solo si es del mismo mapa exterior.
					var entrada: Dictionary = SistemaGuardado.get_entrada_exterior()
					if _misma_clave_mapa(str(entrada.get("mapa_actual", "")), mapa_id) \
							and admin.has_method("obtener_tamano_celdas_mapa"):
						celda = Vector2i(int(entrada.get("cx", 0)), int(entrada.get("cy", 0)))
						tam_mapa = admin.obtener_tamano_celdas_mapa(mapa_id)
			else:
				var jugador = admin.get("jugador")
				if jugador != null and mapa_actual.mapa_rect_px != Rect2():
					var celda_jugador = jugador.get("pos_celda_act")
					if celda_jugador is Vector2i:
						celda = celda_jugador
						tam_mapa = Vector2i(mapa_actual.mapa_rect_px.size / Singleton.TILE_SIZE)
			# Submarinos: el POI de su mapa de superficie, con la celda y el
			# tamaño del propio submarino (InitializeCursorPosition + sUnderwaterMaps).
			if not mapa_actual.poi_mapa_region.is_empty():
				mapa_id = mapa_actual.poi_mapa_region
			casilla_fija = mapa_actual.casilla_mapa_region
	var sexo := "M"
	if SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.jugador:
		sexo = str(SistemaGuardado.datos_vivos.jugador.get("sexo", "M"))
	return {"mapa_id": mapa_id, "sexo": sexo, "celda": celda, "tam_mapa": tam_mapa, "casilla_fija": casilla_fija}

func _buscar_poi_por_mapa(mapa_id: String) -> Dictionary:
	var buscado := mapa_id.strip_edges().to_lower()
	for poi in poi_list:
		if str(poi.get("map_id", "")).to_lower() == buscado \
				or str(poi.get("id", "")).to_lower() == buscado:
			return poi
	return {}

func get_player_tile() -> Vector2i:
	return player_tile

### Encuentros (esqueleto)
func load_encounter_table(table_id: String, table_data: Dictionary) -> void:
	encounter_tables[table_id] = table_data

func get_encounters_for_poi(poi: Dictionary) -> Dictionary:
	if not poi:
		return {}
	if poi.has("encounter_table_id") and encounter_tables.has(poi.encounter_table_id):
		return encounter_tables[poi.encounter_table_id]
	return {}

## Carga metadata de región desde `res://BaseDatos/region_map_metadata.json`.
## `region_key` es la clave dentro del JSON que contiene el array de POIs, p.ej. "hoenn_poi".
## Convierte cada entrada a la forma esperada por este script (id,map_id,tile,tile_size,nombre,prioridad,vuelo)
## y llama a `load_pois()` con el array convertido. Devuelve true si encontró y cargó la clave.
func load_region_metadata(region_key: String) -> bool:
	var path = "res://BaseDatos/region_map_metadata.json"
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		_logear("No se pudo abrir metadata regional: %s" % path)
		return false
	var txt = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed.has("error") and parsed["error"] != OK:
		_logear("Error parseando region_map_metadata.json: %s" % (parsed["error_string"] if parsed.has("error_string") else ""))
		return false
	_logear("Claves en parsed: %s" % str(parsed.keys()))
	var root_dict: Dictionary = {}
	if parsed.has("result") and typeof(parsed["result"]) == TYPE_DICTIONARY:
		root_dict = parsed["result"]
		_logear("Usando parsed['result'] como raíz")
	elif typeof(parsed) == TYPE_DICTIONARY:
		root_dict = parsed
		_logear("Usando parsed directamente como raíz")
	else:
		_logear("region_map_metadata.json no contiene un diccionario en la raíz. parsed: %s" % str(parsed))
		return false
	if not root_dict.has(region_key):
		_logear("No se encontró la clave '%s' en region_map_metadata.json. root_dict: %s" % [region_key, str(root_dict)])
		return false
	var raw = root_dict[region_key]
	if typeof(raw) != TYPE_ARRAY:
		_logear("La clave %s no es un array" % region_key)
		return false
	var converted: Array = []
	for entry in raw:
		# Esperamos claves: id, map_id, nombre, tile [x,y], tile_size [w,h], prioridad, vuelo
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = {}
		p.id = entry.id if entry.has("id") else ""
		p.map_id = entry.map_id if entry.has("map_id") else p.id
		if entry.has("tile") and typeof(entry.tile) == TYPE_ARRAY and entry.tile.size() >= 2:
			p.tile = [int(entry.tile[0]), int(entry.tile[1])]
		else:
			p.tile = [0, 0]
		p.tile_size = entry.tile_size if entry.has("tile_size") else [1, 1]
		p.nombre = entry.nombre if entry.has("nombre") else ""
		p.prioridad = entry.prioridad if entry.has("prioridad") else 0
		p.vuelo = entry.vuelo if entry.has("vuelo") else false
		# conservar campos opcionales si existen
		if entry.has("encounter_table_id"):
			p.encounter_table_id = entry.encounter_table_id
		if entry.has("vuelo_destino") and typeof(entry.vuelo_destino) == TYPE_DICTIONARY:
			p.vuelo_destino = entry.vuelo_destino
		# Secciones en varias partes (sMultiPartMapSections: COLOSALIA): destino y nombre por casilla.
		if entry.has("vuelo_zonas") and typeof(entry.vuelo_zonas) == TYPE_ARRAY:
			p.vuelo_zonas = entry.vuelo_zonas
			p.vuelo_zonas_bandera = str(entry.get("vuelo_zonas_bandera", "")).strip_edges()
		# FLAG_LANDMARK_* que condiciona que el landmark se liste en el panel.
		if entry.has("bandera") and not str(entry.bandera).strip_edges().is_empty():
			p.bandera = str(entry.bandera).strip_edges()
		converted.append(p)
		_logear("POI cargado: %s" % p.nombre)
	if converted.size() > 0:
		load_pois(converted)
		return true
	return false

### Utilidades de depuración
func dbg_print_poi_at_cursor() -> void:
	if not cursor_node:
		return
	var tile = cursor_position_to_tile(_get_node_pos(cursor_node) - cursor_center_offset)
	var tile_clamped = _clamp_tile(tile)
	var list = get_poi_data_at_tile(tile_clamped)
	print("Cursor tile:", tile, " POI:", list)

func _start_cursor_animation() -> void:
	if not cursor_node:
		return
	# Si el propio nodo es AnimatedSprite2D (Godot 4)
	if cursor_node is AnimatedSprite2D:
		var a = cursor_node as AnimatedSprite2D
		if a.sprite_frames:
			var names = a.sprite_frames.get_animation_names()
			if "default" in names:
				a.play("default")
			else:
				a.play()
			return
	# Si el nodo tiene un hijo AnimatedSprite2D
	for child in cursor_node.get_children():
		if child is AnimatedSprite2D:
			var a2 = child as AnimatedSprite2D
			if a2.sprite_frames:
				var names2 = a2.sprite_frames.get_animation_names()
				if "default" in names2:
					a2.play("default")
				else:
					a2.play()
				return
	# Si tiene AnimationPlayer
	var ap = cursor_node.get_node_or_null("AnimationPlayer")
	if ap and ap is AnimationPlayer:
		if ap.has_animation("default"):
			ap.play("default")
		else:
			var anims = ap.get_animation_list()
			if anims.size() > 0:
				ap.play(anims[0])

func _logear(tag: String) -> void:
	print("📍 [MAPA REGION] → %s" % tag)

# Fin de archivo
