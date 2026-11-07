@tool
extends Control
## Vista previa de un mapa (por ruta de escena) con zoom, desplazamiento y
## selección de tile. Los tiles y sprites se clonan como hijos de un Node2D
## dentro del propio Control (sin SubViewport). Usa la escena abierta en el
## editor si existe, para reflejar cambios sin guardar.

signal celda_elegida(celda: Vector2i)

const TAM_TILE := 16.0
const ZOOM_MIN := 0.1
const ZOOM_MAX := 12.0
const UMBRAL_ARRASTRE := 4.0
const COLOR_FONDO := Color(0.11, 0.12, 0.15)
const COLOR_CURSOR := Color(1, 1, 1)
const COLOR_DESTINO := Color(1.0, 0.85, 0.2)

var ruta_mostrada := ""
var _mundo: Node2D
var _overlay: Control
var _limites := Rect2(Vector2.ZERO, Vector2(320, 240))
var _zoom := 1.0
var _origen := Vector2.ZERO
var _cursor := Vector2i.ZERO
var _cursor_dentro := false
var _destino: Variant = null
var _direccion := Vector2.ZERO
var _boton := 0
var _inicio := Vector2.ZERO
var _previa := Vector2.ZERO
var _arrastro := false


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK
	mouse_filter = Control.MOUSE_FILTER_STOP
	_mundo = Node2D.new()
	add_child(_mundo)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_dibujar_overlay)
	add_child(_overlay)
	resized.connect(_overlay.queue_redraw)


func mostrar_ruta(ruta: String) -> void:
	ruta_mostrada = ruta
	for hijo in _mundo.get_children():
		hijo.queue_free()
		_mundo.remove_child(hijo)
	_limites = Rect2(Vector2.ZERO, Vector2(320, 240))
	if not ruta.is_empty():
		_cargar(ruta)
	ajustar()


## Como en el lienzo de conexiones: sin flecha de paso si modo_direccion no es
## FIJA (0), porque la dirección depende de cómo entre el jugador.
func fijar_destino(celda: Variant, direccion: Vector2 = Vector2.ZERO, dar_paso: bool = false, modo_direccion: int = 0) -> void:
	_destino = celda
	_direccion = direccion if dar_paso and modo_direccion == 0 else Vector2.ZERO
	_overlay.queue_redraw()


func ajustar() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	_zoom = clampf(minf((size.x - 24.0) / maxf(16.0, _limites.size.x),
		(size.y - 24.0) / maxf(16.0, _limites.size.y)), ZOOM_MIN, 5.0)
	_origen = size * 0.5 - _limites.get_center() * _zoom
	_aplicar()


func celdas_clonadas() -> int:
	var total := 0
	for hijo in _mundo.get_children():
		if hijo is TileMapLayer:
			total += 1
	return total


func _cargar(ruta: String) -> void:
	var fuente: Node2D = null
	var temporal := false
	for raiz in EditorInterface.get_open_scene_roots() if Engine.is_editor_hint() else []:
		if is_instance_valid(raiz) and raiz.scene_file_path == ruta:
			fuente = raiz as Node2D
			break
	if fuente == null:
		var escena := load(ruta) as PackedScene
		if escena != null:
			fuente = escena.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED) as Node2D
			temporal = true
	if fuente == null:
		return
	var rects: Array[Rect2] = []
	_clonar(fuente, fuente, rects)
	if not rects.is_empty():
		_limites = rects[0]
		for r in rects:
			_limites = _limites.merge(r)
	if temporal:
		fuente.free()


func _clonar(raiz: Node2D, nodo: Node, rects: Array[Rect2]) -> void:
	for hijo in nodo.get_children():
		if not (hijo is Node2D) or _es_warp(hijo):
			continue
		var copia: Node2D = null
		if hijo is TileMapLayer:
			var capa := TileMapLayer.new()
			capa.tile_set = hijo.tile_set
			capa.tile_map_data = hijo.tile_map_data
			capa.collision_enabled = false
			capa.navigation_enabled = false
			capa.occlusion_enabled = false
			capa.y_sort_enabled = hijo.y_sort_enabled
			copia = capa
			var usado: Rect2i = hijo.get_used_rect()
			if usado.size != Vector2i.ZERO:
				var rect := Rect2(Vector2(usado.position) * TAM_TILE, Vector2(usado.size) * TAM_TILE)
				rects.append(_relativa(raiz, hijo) * rect)
		elif hijo is Sprite2D:
			var sprite := Sprite2D.new()
			for propiedad in ["texture", "centered", "offset", "flip_h", "flip_v", "region_enabled", "region_rect", "hframes", "vframes", "frame"]:
				sprite.set(propiedad, hijo.get(propiedad))
			copia = sprite
		if copia != null:
			copia.transform = _relativa(raiz, hijo)
			copia.z_index = hijo.z_index
			copia.modulate = hijo.modulate
			copia.visible = _visible_hasta(raiz, hijo)
			_mundo.add_child(copia)
		if hijo.scene_file_path.is_empty():
			_clonar(raiz, hijo, rects)


static func _relativa(raiz: Node2D, nodo: Node2D) -> Transform2D:
	return raiz.global_transform.affine_inverse() * nodo.global_transform


static func _visible_hasta(raiz: Node, nodo: Node) -> bool:
	var actual := nodo
	while actual != null and actual != raiz:
		if actual is CanvasItem and not (actual as CanvasItem).visible:
			return false
		actual = actual.get_parent()
	return true


static func _es_warp(nodo: Node) -> bool:
	var script := nodo.get_script() as Script
	while script != null:
		if script.resource_path == "res://scripts/warp.gd":
			return true
		script = script.get_base_script()
	return false


func _aplicar() -> void:
	_mundo.position = _origen
	_mundo.scale = Vector2(_zoom, _zoom)
	_overlay.queue_redraw()


func _celda_en(pos: Vector2) -> Vector2i:
	return Vector2i(((pos - _origen) / (_zoom * TAM_TILE)).floor())


func _rect_celda(celda: Vector2i) -> Rect2:
	return Rect2(Vector2(celda) * TAM_TILE * _zoom + _origen, Vector2.ONE * TAM_TILE * _zoom)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _overlay != null:
		_cursor_dentro = false
		_overlay.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		if _boton != 0:
			if not _arrastro and pos.distance_to(_inicio) >= UMBRAL_ARRASTRE:
				_arrastro = true
			if _arrastro:
				_origen += pos - _previa
				_aplicar()
		_previa = pos
		_cursor_dentro = true
		_cursor = _celda_en(pos)
		_overlay.queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					var punto := (mb.position - _origen) / _zoom
					_zoom = clampf(_zoom * (1.2 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), ZOOM_MIN, ZOOM_MAX)
					_origen = mb.position - punto * _zoom
					_aplicar()
				accept_event()
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					grab_focus()
					celda_elegida.emit(_celda_en(mb.position))
				accept_event()
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if mb.pressed:
					_boton = mb.button_index
					_inicio = mb.position
					_previa = mb.position
					_arrastro = false
					grab_focus()
				else:
					if _boton == MOUSE_BUTTON_RIGHT and not _arrastro:
						celda_elegida.emit(_celda_en(mb.position))
					_boton = 0
				accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_FONDO)


func _dibujar_overlay() -> void:
	if _zoom * TAM_TILE >= 20.0:
		_dibujar_cuadricula()
	if _destino != null:
		var rect := _rect_celda(Vector2i(_destino))
		_overlay.draw_rect(rect, Color(COLOR_DESTINO, 0.35))
		_overlay.draw_rect(rect, COLOR_DESTINO, false, 2.0)
		if _direccion != Vector2.ZERO:
			var centro := rect.get_center()
			var fin := centro + _direccion * rect.size.x * 0.9
			_overlay.draw_line(centro, fin, COLOR_DESTINO, 2.0)
			_overlay.draw_circle(fin, 3.0, COLOR_DESTINO)
	if _cursor_dentro:
		var rect := _rect_celda(_cursor)
		_overlay.draw_rect(rect, Color(COLOR_CURSOR, 0.2))
		_overlay.draw_rect(rect, COLOR_CURSOR, false, 1.5)
		var texto := "%d, %d" % [_cursor.x, _cursor.y]
		var fuente := ThemeDB.fallback_font
		var medida := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		_overlay.draw_rect(Rect2(Vector2(4, 4), medida + Vector2(10, 6)), Color(0, 0, 0, 0.7))
		_overlay.draw_string(fuente, Vector2(9, 7 + fuente.get_ascent(14)), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _dibujar_cuadricula() -> void:
	var paso := TAM_TILE * _zoom
	var color := Color(1, 1, 1, 0.08)
	var x := fposmod(_origen.x, paso)
	while x < size.x:
		_overlay.draw_line(Vector2(x, 0), Vector2(x, size.y), color)
		x += paso
	var y := fposmod(_origen.y, paso)
	while y < size.y:
		_overlay.draw_line(Vector2(0, y), Vector2(size.x, y), color)
		y += paso
