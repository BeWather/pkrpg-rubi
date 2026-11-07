@tool
extends Control
## Vista aislada de las capas de un mapa. Nunca añade scripts del mapa al árbol
## del editor: solo clona TileMapLayer y Sprite2D para su representación.

signal warp_elegido(ruta_nodo: NodePath)
signal celda_elegida(celda: Vector2i)
signal cursor_en_celda(celda: Vector2i)
signal accion_cancelada

const TAM_TILE := 16.0
const COLOR_WARP := Color(0.7, 0.5, 1.0)
const COLOR_SIN_DESTINO := Color(1.0, 0.45, 0.4)
const COLOR_SELECCION := Color(0.3, 1.0, 0.65)

var _viewport: SubViewport
var _raiz_visual: Node2D
var _mapa: Dictionary = {}
var _zoom := 1.0
var _desplazamiento := Vector2.ZERO
var _limites := Rect2(Vector2.ZERO, Vector2(320, 240))
var _seleccion := NodePath("")
var _llegada: Variant = null
var _paso := Vector2.ZERO
var _modo_celda := false
var _paneando := false
var _ultima_posicion := Vector2.ZERO
var _cursor := Vector2i.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(240, 260)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_viewport = SubViewport.new()
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.size = Vector2i(400, 300)
	add_child(_viewport)
	resized.connect(_ajustar_viewport)
	_ajustar_viewport()


func mostrar_mapa(mapa: Dictionary) -> void:
	_mapa = mapa
	_seleccion = NodePath("")
	_llegada = null
	if is_instance_valid(_raiz_visual):
		_raiz_visual.hide()
		_raiz_visual.queue_free()
	_raiz_visual = Node2D.new()
	_viewport.add_child(_raiz_visual)
	_limites = Rect2(Vector2.ZERO, Vector2(320, 240))
	var ruta := str(mapa.get("ruta", ""))
	if not ruta.is_empty():
		var fuente := preload("res://addons/tilemap_inspector/datos_conexiones_warp.gd").raiz_abierta(ruta) as Node2D
		var temporal := false
		if fuente == null:
			var escena := load(ruta) as PackedScene
			if escena != null:
				fuente = escena.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED) as Node2D
				temporal = true
		if fuente != null:
			var limites: Array[Rect2] = []
			_clonar_visuales(fuente, fuente, limites)
			if not limites.is_empty():
				_limites = limites[0]
				for r in limites:
					_limites = _limites.merge(r)
			if temporal:
				fuente.free()
	call_deferred("ajustar_mapa")
	queue_redraw()


func _clonar_visuales(raiz: Node2D, nodo: Node, limites: Array[Rect2]) -> void:
	for hijo in nodo.get_children():
		if not (hijo is Node2D):
			continue
		var visual: Node2D = null
		if hijo is TileMapLayer:
			var capa := TileMapLayer.new()
			capa.tile_set = hijo.tile_set
			capa.tile_map_data = hijo.tile_map_data
			capa.collision_enabled = false
			capa.navigation_enabled = false
			capa.occlusion_enabled = false
			visual = capa
			var celdas: Rect2i = hijo.get_used_rect()
			if celdas.size != Vector2i.ZERO:
				var rect := Rect2(Vector2(celdas.position) * TAM_TILE, Vector2(celdas.size) * TAM_TILE)
				var xf: Transform2D = raiz.global_transform.affine_inverse() * hijo.global_transform
				limites.append(xf * rect)
		elif hijo is Sprite2D and not _es_descendiente_warp(raiz, hijo):
			var sprite := Sprite2D.new()
			sprite.texture = hijo.texture
			sprite.centered = hijo.centered
			sprite.offset = hijo.offset
			sprite.region_enabled = hijo.region_enabled
			sprite.region_rect = hijo.region_rect
			sprite.hframes = hijo.hframes
			sprite.vframes = hijo.vframes
			sprite.frame = hijo.frame
			visual = sprite
		if visual != null:
			visual.transform = raiz.global_transform.affine_inverse() * hijo.global_transform
			visual.z_index = (hijo as CanvasItem).z_index
			visual.modulate = (hijo as CanvasItem).modulate
			visual.visible = _visible_en_mapa(raiz, hijo)
			_raiz_visual.add_child(visual)
		if hijo.scene_file_path.is_empty() and not _es_descendiente_warp(raiz, hijo):
			_clonar_visuales(raiz, hijo, limites)


func _visible_en_mapa(raiz: Node, nodo: Node) -> bool:
	var actual := nodo
	while actual != null and actual != raiz:
		if actual is CanvasItem and not (actual as CanvasItem).visible:
			return false
		actual = actual.get_parent()
	return true


func _es_descendiente_warp(raiz: Node, nodo: Node) -> bool:
	var actual := nodo
	while actual != null and actual != raiz:
		var script := actual.get_script() as Script
		while script != null:
			if script.resource_path == "res://scripts/warp.gd":
				return true
			script = script.get_base_script()
		actual = actual.get_parent()
	return false


func _ajustar_viewport() -> void:
	if is_instance_valid(_viewport):
		_viewport.size = Vector2i(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))
	queue_redraw()


func ajustar_mapa() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	_zoom = clampf(minf((size.x - 32.0) / maxf(16.0, _limites.size.x),
		(size.y - 32.0) / maxf(16.0, _limites.size.y)), 0.2, 5.0)
	_desplazamiento = size * 0.5 - _limites.get_center() * _zoom
	_actualizar_transform()


func seleccionar_warp(ruta: NodePath) -> void:
	_seleccion = ruta
	queue_redraw()


## Solo se dibuja la flecha de paso con modo_direccion FIJA (0): con MANTENER o
## INVERTIR la dirección depende de cómo entre el jugador.
func marcar_llegada(celda: Variant, direccion: Vector2 = Vector2.ZERO, dar_paso: bool = false, modo_direccion: int = 0) -> void:
	_llegada = celda
	_paso = direccion if dar_paso and modo_direccion == 0 else Vector2.ZERO
	queue_redraw()


func elegir_celda(activo: bool) -> void:
	_modo_celda = activo
	mouse_default_cursor_shape = Control.CURSOR_CROSS if activo else Control.CURSOR_ARROW
	if activo:
		grab_focus()
	queue_redraw()


func _actualizar_transform() -> void:
	if is_instance_valid(_viewport):
		_viewport.canvas_transform = Transform2D(Vector2(_zoom, 0), Vector2(0, _zoom), _desplazamiento)
	queue_redraw()


func _posicion_en_pantalla(celda: Vector2) -> Vector2:
	return (celda * TAM_TILE + Vector2(8, 8)) * _zoom + _desplazamiento


func _celda_en(pos: Vector2) -> Vector2i:
	return Vector2i((((pos - _desplazamiento) / _zoom) / TAM_TILE).floor())


func _gui_input(event: InputEvent) -> void:
	if _modo_celda and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		accion_cancelada.emit()
		accept_event()
	elif event is InputEventMouseMotion:
		var movimiento := event as InputEventMouseMotion
		if _paneando:
			_desplazamiento += movimiento.position - _ultima_posicion
			_actualizar_transform()
		_ultima_posicion = movimiento.position
		var nueva := _celda_en(movimiento.position)
		if nueva != _cursor:
			_cursor = nueva
			cursor_en_celda.emit(nueva)
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if _modo_celda and mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				accion_cancelada.emit()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var punto: Vector2 = (mb.position - _desplazamiento) / _zoom
				_zoom = clampf(_zoom * (1.25 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), 0.2, 8.0)
				_desplazamiento = mb.position - punto * _zoom
				_actualizar_transform()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			_paneando = mb.pressed
			_ultima_posicion = mb.position
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var celda := _celda_en(mb.position)
			if _modo_celda:
				celda_elegida.emit(celda)
			else:
				var coincidencias: Array[Dictionary] = []
				for warp in _mapa.get("warps", []):
					if warp.celda == celda:
						coincidencias.append(warp)
				if not coincidencias.is_empty():
					var indice := 0
					for i in coincidencias.size():
						if coincidencias[i].nodo == _seleccion:
							indice = (i + 1) % coincidencias.size()
							break
					warp_elegido.emit(coincidencias[indice].nodo)
			accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.13, 0.16))
	if is_instance_valid(_viewport):
		draw_texture_rect(_viewport.get_texture(), Rect2(Vector2.ZERO, size), false)
	if _mapa.is_empty():
		return
	var fuente := ThemeDB.fallback_font
	var por_celda: Dictionary = {}
	for warp in _mapa.get("warps", []):
		var celda: Vector2i = warp.celda
		por_celda[celda] = int(por_celda.get(celda, 0)) + 1
	for warp in _mapa.get("warps", []):
		var celda: Vector2i = warp.celda
		var punto := _posicion_en_pantalla(Vector2(celda))
		if not Rect2(Vector2.ZERO, size).grow(12).has_point(punto):
			continue
		var elegido: bool = warp.nodo == _seleccion
		var color: Color = COLOR_SELECCION if elegido else (COLOR_SIN_DESTINO if str(warp.destino).is_empty() else COLOR_WARP)
		draw_circle(punto, 10.0 if elegido else 7.0, Color(0, 0, 0, 0.85))
		draw_circle(punto, 8.0 if elegido else 5.0, color)
		if int(por_celda[celda]) > 1:
			draw_string(fuente, punto + Vector2(7, -7), "×%d" % por_celda[celda], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if _llegada != null:
		var pos := _posicion_en_pantalla(Vector2(_llegada))
		draw_circle(pos, 10.0, Color(0, 0, 0, 0.85))
		draw_arc(pos, 9.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.2), 3.0)
		if _paso != Vector2.ZERO:
			var fin := pos + _paso * TAM_TILE * _zoom
			draw_line(pos, fin, Color(1.0, 0.9, 0.2), 2.0)
			draw_circle(fin, 3.0, Color(1.0, 0.9, 0.2))
	if _modo_celda:
		var rect := Rect2(Vector2(_cursor) * TAM_TILE * _zoom + _desplazamiento, Vector2.ONE * TAM_TILE * _zoom)
		draw_rect(rect, Color(0.3, 1, 0.65, 0.3))
		draw_rect(rect, COLOR_SELECCION, false, 2.0)
