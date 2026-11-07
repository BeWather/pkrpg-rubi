@tool
extends EditorPlugin
## Lápiz de tiles animados: pinta en el TileMapLayer seleccionado tiles cuyo frame
## depende de la posición, calculando el tile de cada celda por sus coordenadas absolutas.
##
## - Flores de Mauville (atlas flores_mauville.png): intercala color y variante en
##   diagonal; la celda (x+1, y+1) repite la flor de (x, y), igual que en el mapa original.
##   Filas 0-7 = flor rosa (variantes 0-7), filas 8-15 = flor azul.
## - Flores de Ciudad Colosalia (atlas flores_colosalia.png, Ever Grande de la decomp):
##   un color por botón (A = rosa/naranja, B = amarillo/azul), sin damero. La variante
##   de cada celda es (y - x) mod 8, igual que los metatiles 0x288-0x29F del map.bin.
##   Filas 0-7 = paleta 10 (variantes 0-7), filas 8-15 = paleta 11.
## - Ola del estanque de la Ruta 104 (atlas agua_estanque.png, Rustboro0 de la decomp):
##   fila = (y - x + 2) mod 8, igual que los metatiles 0x208-0x20F del map.bin.
## - Humo de la Senda Ígnea (atlas humo_senda_ignea.png, Lavaridge de la decomp):
##   dos variantes desfasadas medio ciclo (A y B). En el original se colocan a mano,
##   así que cada botón pinta siempre su variante, sin patrón por posición.
##
## Clic izquierdo pinta, clic derecho borra (solo tiles del atlas activo). Un trazo = un Ctrl+Z.
## Shift + arrastrar: rectángulo, que se aplica al soltar (Esc o el otro botón lo cancelan).

const TEXTURA_FLORES: String = "res://graficos/tilesets/flores_mauville.png"
const TEXTURA_FLORES_COLOSALIA: String = "res://graficos/tilesets/flores_colosalia.png"
const TEXTURA_AGUA: String = "res://graficos/tilesets/agua_estanque.png"
const TEXTURA_HUMO: String = "res://graficos/tilesets/humo_senda_ignea.png"
const TAM_TILE: int = 16
const AYUDA: String = "
Clic izq.: pintar · Clic der.: borrar
Shift + arrastrar: rectángulo (Esc cancela)"
const AYUDA_HUMO: String = "
Es transparente: píntalo en una capa encima del suelo (p. ej. Rocas)." + AYUDA
## Por encima de este número de celdas la vista previa del rectángulo no dibuja cada tile.
const MAX_CELDAS_VISTA_PREVIA: int = 4096

enum Modo { NINGUNO = -1, ROSA_PRIMERO = 0, AZUL_PRIMERO = 1, OLA_ESTANQUE = 2, HUMO_A = 3, HUMO_B = 4, COLOSALIA_A = 5, COLOSALIA_B = 6 }

var _barra: HBoxContainer
var _boton_rosa: Button
var _boton_azul: Button
var _boton_colosalia_a: Button
var _boton_colosalia_b: Button
var _boton_ola: Button
var _boton_humo_a: Button
var _boton_humo_b: Button

var _capa: TileMapLayer = null
var _source_flores: int = -1
var _source_colosalia: int = -1
var _source_agua: int = -1
var _source_humo: int = -1
var _modo: int = Modo.NINGUNO

var _pintando: bool = false
var _borrando: bool = false
var _boton_trazo: int = MOUSE_BUTTON_NONE
## Trazo en rectángulo (Shift): no toca la capa hasta soltar; _ultima_celda es la esquina opuesta.
var _rectangulo: bool = false
var _inicio_rect: Vector2i = Vector2i.ZERO
var _ultima_celda: Vector2i = Vector2i.ZERO
## Vector2i -> [source_id, atlas_coords, alternative] previos al trazo (para deshacer).
var _cambios: Dictionary = {}

var _hay_hover: bool = false
var _celda_hover: Vector2i = Vector2i.ZERO


func _enter_tree() -> void:
	_barra = HBoxContainer.new()
	_barra.add_child(VSeparator.new())
	_boton_rosa = _crear_boton(TEXTURA_FLORES, 0, "Rosa", "Lápiz de flores — empieza con ROSA en (0,0)" + AYUDA)
	_boton_azul = _crear_boton(TEXTURA_FLORES, 8, "Azul", "Lápiz de flores — empieza con AZUL en (0,0)" + AYUDA)
	_boton_colosalia_a = _crear_boton(TEXTURA_FLORES_COLOSALIA, 0, "Col. A", "Flores de Colosalia — rosa y naranja (variante por coordenadas)" + AYUDA)
	_boton_colosalia_b = _crear_boton(TEXTURA_FLORES_COLOSALIA, 8, "Col. B", "Flores de Colosalia — amarillo y azul (variante por coordenadas)" + AYUDA)
	_boton_ola = _crear_boton(TEXTURA_AGUA, 0, "Ola", "Ola del estanque (Ruta 104) — el tile sale de las coordenadas de la celda" + AYUDA)
	# Columna 2 de la fila A = burbuja grande; la fila B empieza en ese mismo frame.
	_boton_humo_a = _crear_boton(TEXTURA_HUMO, 0, "Humo A", "Humo de la Senda Ígnea — variante A (fase 0)" + AYUDA_HUMO, 2)
	_boton_humo_b = _crear_boton(TEXTURA_HUMO, 1, "Humo B", "Humo de la Senda Ígnea — variante B (desfasada medio ciclo)" + AYUDA_HUMO, 0)
	_boton_humo_a.text = "A"
	_boton_humo_b.text = "B"
	_barra.add_child(_boton_rosa)
	_barra.add_child(_boton_azul)
	_barra.add_child(_boton_colosalia_a)
	_barra.add_child(_boton_colosalia_b)
	_barra.add_child(_boton_ola)
	_barra.add_child(_boton_humo_a)
	_barra.add_child(_boton_humo_b)
	_barra.hide()
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _barra)
	_boton_rosa.toggled.connect(func(activo: bool) -> void: _al_alternar(Modo.ROSA_PRIMERO, activo))
	_boton_azul.toggled.connect(func(activo: bool) -> void: _al_alternar(Modo.AZUL_PRIMERO, activo))
	_boton_colosalia_a.toggled.connect(func(activo: bool) -> void: _al_alternar(Modo.COLOSALIA_A, activo))
	_boton_colosalia_b.toggled.connect(func(activo: bool) -> void: _al_alternar(Modo.COLOSALIA_B, activo))
	_boton_ola.toggled.connect(func(activo: bool) -> void: _al_alternar(Modo.OLA_ESTANQUE, activo))
	_boton_humo_a.toggled.connect(func(activo: bool) -> void: _al_alternar(Modo.HUMO_A, activo))
	_boton_humo_b.toggled.connect(func(activo: bool) -> void: _al_alternar(Modo.HUMO_B, activo))


func _exit_tree() -> void:
	_terminar_trazo()
	if is_instance_valid(_barra):
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _barra)
		_barra.queue_free()
	_barra = null
	_capa = null


func _handles(object: Object) -> bool:
	return object is TileMapLayer


func _edit(object: Object) -> void:
	_terminar_trazo()
	_capa = object as TileMapLayer
	_source_flores = _buscar_source(TEXTURA_FLORES)
	_source_agua = _buscar_source(TEXTURA_AGUA)
	_source_colosalia = _buscar_source(TEXTURA_FLORES_COLOSALIA)
	for boton: Button in [_boton_rosa, _boton_azul]:
		boton.disabled = _source_flores == -1
	for boton: Button in [_boton_colosalia_a, _boton_colosalia_b]:
		boton.disabled = _source_colosalia == -1
	_boton_ola.disabled = _source_agua == -1
	_source_humo = _buscar_source(TEXTURA_HUMO)
	for boton: Button in [_boton_humo_a, _boton_humo_b]:
		boton.disabled = _source_humo == -1
	if _source_activo() == -1:
		_desactivar()
	_hay_hover = false
	update_overlays()


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_barra):
		_barra.visible = visible
	if not visible:
		_desactivar()


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _modo == Modo.NINGUNO or not _capa_valida():
		return false

	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and tecla.keycode == KEY_ESCAPE and _rectangulo:
			_cancelar_rectangulo()
			return true
		return false

	if event is InputEventMouseMotion:
		var celda: Vector2i = _celda_bajo((event as InputEventMouseMotion).position)
		if not _hay_hover or celda != _celda_hover:
			_hay_hover = true
			_celda_hover = celda
			update_overlays()
		if _rectangulo:
			_ultima_celda = celda
			return true
		if _pintando or _borrando:
			# Interpola para no dejar huecos al arrastrar rápido.
			for c: Vector2i in Geometry2D.bresenham_line(_ultima_celda, celda):
				_aplicar(c)
			_ultima_celda = celda
			return true
		return false

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return false
		var hay_trazo: bool = _pintando or _borrando
		if mb.pressed:
			if not hay_trazo:
				_pintando = mb.button_index == MOUSE_BUTTON_LEFT
				_borrando = not _pintando
				_boton_trazo = mb.button_index
				_rectangulo = mb.shift_pressed
				_cambios.clear()
				_ultima_celda = _celda_bajo(mb.position)
				_inicio_rect = _ultima_celda
				if not _rectangulo:
					_aplicar(_ultima_celda)
				update_overlays()
			elif _rectangulo:
				_cancelar_rectangulo()  # El otro botón cancela el rectángulo; en trazo libre se ignora.
		elif hay_trazo and mb.button_index == _boton_trazo:
			if _rectangulo:
				for celda: Vector2i in _celdas_rectangulo():
					_aplicar(celda)
			_terminar_trazo()
			update_overlays()
		return true

	return false


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if _modo == Modo.NINGUNO or not _hay_hover or not _capa_valida():
		return
	var src := _capa.tile_set.get_source(_source_activo()) as TileSetAtlasSource
	var tam := Vector2(_capa.tile_set.tile_size)
	var borde: Color = Color(1.0, 0.3, 0.3, 0.9) if _borrando else Color(1.0, 1.0, 1.0, 0.9)
	overlay.draw_set_transform_matrix(_transform_lienzo())
	if _rectangulo:
		var celdas: Array[Vector2i] = _celdas_rectangulo()
		var desde: Vector2i = _inicio_rect.min(_ultima_celda)
		var hasta: Vector2i = _inicio_rect.max(_ultima_celda)
		var total := Rect2(_capa.map_to_local(desde) - tam / 2.0, tam * Vector2(hasta - desde + Vector2i.ONE))
		if _borrando:
			overlay.draw_rect(total, Color(1.0, 0.3, 0.3, 0.35))
		elif celdas.size() <= MAX_CELDAS_VISTA_PREVIA:
			for celda: Vector2i in celdas:
				_dibujar_tile(overlay, src, celda, tam)
		else:
			overlay.draw_rect(total, Color(1.0, 1.0, 1.0, 0.25))
		overlay.draw_rect(total, borde, false, -1.0)
	else:
		var rect := Rect2(_capa.map_to_local(_celda_hover) - tam / 2.0, tam)
		if _borrando:
			overlay.draw_rect(rect, Color(1.0, 0.3, 0.3, 0.35))
		else:
			_dibujar_tile(overlay, src, _celda_hover, tam)
		overlay.draw_rect(rect, borde, false, -1.0)
	overlay.draw_set_transform_matrix(Transform2D.IDENTITY)
	if _rectangulo:
		var medida: Vector2i = (_ultima_celda - _inicio_rect).abs() + Vector2i.ONE
		var pos: Vector2 = _transform_lienzo() * (_capa.map_to_local(_ultima_celda) + tam / 2.0)
		overlay.draw_string(ThemeDB.fallback_font, pos + Vector2(6.0, 16.0), "%d×%d" % [medida.x, medida.y],
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, borde)


func _dibujar_tile(overlay: Control, src: TileSetAtlasSource, celda: Vector2i, tam: Vector2) -> void:
	var rect := Rect2(_capa.map_to_local(celda) - tam / 2.0, tam)
	var region: Rect2i = src.get_tile_texture_region(_coords_tile(celda))
	overlay.draw_texture_rect_region(src.texture, rect, region, Color(1.0, 1.0, 1.0, 0.75))


# ─── Patrón ───────────────────────────────────────────────────────────

## Coordenadas en el atlas del tile que corresponde a una celda en el modo activo.
func _coords_tile(celda: Vector2i) -> Vector2i:
	match _modo:
		Modo.OLA_ESTANQUE:
			return Vector2i(0, _fila_ola(celda))
		Modo.HUMO_A:
			return Vector2i(0, 0)
		Modo.HUMO_B:
			return Vector2i(0, 1)
		Modo.COLOSALIA_A, Modo.COLOSALIA_B:
			return Vector2i(0, _fila_colosalia(celda))
	return Vector2i(0, _fila_flor(celda))


## Fila del atlas para una celda. Con ROSA_PRIMERO: (0,0) → fila 0, (1,0) → fila 15.
## El color alterna en damero y, como en el mapa original, la variante avanza +1
## hacia la izquierda y +1 hacia abajo: la diagonal (x+1, y+1) repite flor y la
## ola viaja de arriba-derecha a abajo-izquierda, a favor de la inclinación del
## dibujo. Usa coordenadas absolutas para que trazos separados encajen entre sí.
func _fila_flor(celda: Vector2i) -> int:
	var color: int = (celda.x + celda.y + _modo) & 1
	var variante: int = posmod(celda.y - celda.x, 8)
	return color * 8 + variante


## Fila del atlas de Colosalia: el color lo fija el botón (A = filas 0-7, B = 8-15) y la
## variante es (y - x) mod 8: en el map.bin de Ever Grande la casilla k de la ola
## (metatiles 0x288 + k) sube +1 hacia abajo y baja -1 hacia la derecha.
func _fila_colosalia(celda: Vector2i) -> int:
	var color: int = 1 if _modo == Modo.COLOSALIA_B else 0
	return color * 8 + posmod(celda.y - celda.x, 8)


## Fila del atlas de la ola: grupo k de Rustboro0 (metatile 0x208 + k), con
## k = (y - x + 2) mod 8 como en el map.bin de la Ruta 104. Cada grupo va un paso
## por detrás del anterior, así que la estela avanza hacia abajo-izquierda.
func _fila_ola(celda: Vector2i) -> int:
	return posmod(celda.y - celda.x + 2, 8)


# ─── Pintado ──────────────────────────────────────────────────────────

func _aplicar(celda: Vector2i) -> void:
	var source_id: int = _source_activo()
	if _borrando and _capa.get_cell_source_id(celda) != source_id:
		return  # El borrador solo quita tiles del atlas activo, nunca otros de la capa.
	if not _cambios.has(celda):
		_cambios[celda] = [
			_capa.get_cell_source_id(celda),
			_capa.get_cell_atlas_coords(celda),
			_capa.get_cell_alternative_tile(celda),
		]
	if _pintando:
		_capa.set_cell(celda, source_id, _coords_tile(celda), 0)
	else:
		_capa.erase_cell(celda)


func _terminar_trazo() -> void:
	if not (_pintando or _borrando):
		return
	var que: String = "flores"
	match _modo:
		Modo.OLA_ESTANQUE:
			que = "ola"
		Modo.HUMO_A, Modo.HUMO_B:
			que = "humo"
	var nombre: String = ("Pintar " if _pintando else "Borrar ") + que + (" (rectángulo)" if _rectangulo else "")
	_pintando = false
	_borrando = false
	_rectangulo = false
	_boton_trazo = MOUSE_BUTTON_NONE
	if _cambios.is_empty() or not is_instance_valid(_capa):
		_cambios.clear()
		return
	var ur: EditorUndoRedoManager = get_undo_redo()
	ur.create_action(nombre, UndoRedo.MERGE_DISABLE, _capa)
	for celda: Vector2i in _cambios:
		var previo: Array = _cambios[celda]
		ur.add_do_method(_capa, &"set_cell", celda,
			_capa.get_cell_source_id(celda),
			_capa.get_cell_atlas_coords(celda),
			_capa.get_cell_alternative_tile(celda))
		ur.add_undo_method(_capa, &"set_cell", celda, previo[0], previo[1], previo[2])
	ur.commit_action(false)  # Los tiles ya están puestos; solo registra el historial.
	_cambios.clear()


## El rectángulo aún no tocó la capa, así que cancelarlo solo descarta el estado.
func _cancelar_rectangulo() -> void:
	_cambios.clear()
	_terminar_trazo()
	update_overlays()


func _celdas_rectangulo() -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	var desde: Vector2i = _inicio_rect.min(_ultima_celda)
	var hasta: Vector2i = _inicio_rect.max(_ultima_celda)
	for y: int in range(desde.y, hasta.y + 1):
		for x: int in range(desde.x, hasta.x + 1):
			celdas.append(Vector2i(x, y))
	return celdas


# ─── Botones y estado ─────────────────────────────────────────────────

func _crear_boton(ruta_textura: String, fila: int, texto: String, tooltip: String, columna: int = 0) -> Button:
	var boton := Button.new()
	boton.toggle_mode = true
	boton.flat = true
	boton.tooltip_text = tooltip
	boton.disabled = true
	var textura: Texture2D = load(ruta_textura) as Texture2D if ResourceLoader.exists(ruta_textura) else null
	if textura != null:
		var icono := AtlasTexture.new()
		icono.atlas = textura
		icono.region = Rect2(columna * TAM_TILE, fila * TAM_TILE, TAM_TILE, TAM_TILE)
		boton.icon = icono
	else:
		boton.text = texto
	return boton


func _al_alternar(modo: int, activo: bool) -> void:
	_terminar_trazo()
	if activo:
		_modo = modo
		for boton: Button in _botones():
			if boton != _boton_de(modo):
				boton.set_pressed_no_signal(false)
		# Con el panel TileMap cerrado, el editor nativo ignora los clics del lienzo
		# y no pinta a la vez que el lápiz.
		hide_bottom_panel()
	elif _modo == modo:
		_modo = Modo.NINGUNO
	update_overlays()


func _desactivar() -> void:
	_terminar_trazo()
	_modo = Modo.NINGUNO
	_hay_hover = false
	for boton: Button in _botones():
		if is_instance_valid(boton):
			boton.set_pressed_no_signal(false)
	update_overlays()


func _botones() -> Array[Button]:
	return [_boton_rosa, _boton_azul, _boton_colosalia_a, _boton_colosalia_b, _boton_ola, _boton_humo_a, _boton_humo_b]


func _boton_de(modo: int) -> Button:
	match modo:
		Modo.ROSA_PRIMERO:
			return _boton_rosa
		Modo.AZUL_PRIMERO:
			return _boton_azul
		Modo.COLOSALIA_A:
			return _boton_colosalia_a
		Modo.COLOSALIA_B:
			return _boton_colosalia_b
		Modo.OLA_ESTANQUE:
			return _boton_ola
		Modo.HUMO_A:
			return _boton_humo_a
		Modo.HUMO_B:
			return _boton_humo_b
	return null


func _source_activo() -> int:
	match _modo:
		Modo.ROSA_PRIMERO, Modo.AZUL_PRIMERO:
			return _source_flores
		Modo.COLOSALIA_A, Modo.COLOSALIA_B:
			return _source_colosalia
		Modo.OLA_ESTANQUE:
			return _source_agua
		Modo.HUMO_A, Modo.HUMO_B:
			return _source_humo
	return -1


func _buscar_source(ruta_textura: String) -> int:
	if _capa == null or _capa.tile_set == null:
		return -1
	var ts: TileSet = _capa.tile_set
	for i: int in ts.get_source_count():
		var id: int = ts.get_source_id(i)
		var src := ts.get_source(id) as TileSetAtlasSource
		if src != null and src.texture != null and src.texture.resource_path == ruta_textura:
			return id
	return -1


func _capa_valida() -> bool:
	return is_instance_valid(_capa) and _capa.is_inside_tree() and _source_activo() != -1


## Transform de coordenadas locales de la capa a píxeles del lienzo del editor.
## Incluye el zoom/desplazamiento de la vista 2D (global_canvas_transform), igual
## que el editor nativo de TileMap; sin él la celda se desvía al alejarse del origen.
func _transform_lienzo() -> Transform2D:
	return _capa.get_viewport().global_canvas_transform * _capa.get_global_transform_with_canvas()


func _celda_bajo(pos_viewport: Vector2) -> Vector2i:
	var local: Vector2 = _transform_lienzo().affine_inverse() * pos_viewport
	return _capa.local_to_map(local)
