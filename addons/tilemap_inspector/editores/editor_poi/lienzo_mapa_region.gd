@tool
extends Control
class_name LienzoMapaRegion
## Vista del mapa regional. Las coordenadas de metadata empiezan visualmente una
## columna y dos filas dentro del PNG: el margen superior/izquierdo no es editable.

signal zona_cambiada(tile: Vector2i, tile_size: Vector2i)
signal poi_seleccionado(indice: int)
signal cursor_tile_cambiado(tile: Vector2i, valida: bool, cantidad_pois: int)

const RUTA_MAPA := "res://UI/mapa_region/region_hoenn.png"
const TAM_TILE := 8
const COLUMNAS := 28
const FILAS := 15
## El tile lógico (0,0) está dibujado en el tile visual (1,2) del PNG.
const ORIGEN_VISUAL_TILES := Vector2i(1, 2)
const MODO_EDITAR := 0
const MODO_SELECCIONAR := 1
const COLOR_OTRO := Color(0.15, 0.65, 1.0, 0.22)
const COLOR_SELECCION := Color(1.0, 0.76, 0.12, 0.38)
const COLOR_BORDE := Color(1.0, 0.88, 0.25, 1.0)

var zoom: int = 2:
	set(valor):
		zoom = clampi(valor, 2, 4)
		custom_minimum_size = _tam_mapa() * zoom
		queue_redraw()
var editable := true
var modo := MODO_EDITAR:
	set(valor):
		modo = clampi(valor, MODO_EDITAR, MODO_SELECCIONAR)
		_arrastrando = false
		mouse_default_cursor_shape = Control.CURSOR_CROSS if modo == MODO_EDITAR else Control.CURSOR_POINTING_HAND
		queue_redraw()
var _textura: Texture2D = null
var _pois: Array[Dictionary] = []
var _indice_seleccionado := -1
var _tile := Vector2i.ZERO
var _tile_size := Vector2i.ONE
var _arrastrando := false
var _origen_arrastre := Vector2i.ZERO
var _actual_arrastre := Vector2i.ZERO
var _tile_hover := Vector2i(-1, -1)
var _pulso := 0.0
var _ultima_celda_seleccion := Vector2i(-1, -1)
var _ultimo_hit := -1


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	custom_minimum_size = _tam_mapa() * zoom


func _ready() -> void:
	if ResourceLoader.exists(RUTA_MAPA):
		_textura = load(RUTA_MAPA) as Texture2D
		custom_minimum_size = _tam_mapa() * zoom
	mouse_exited.connect(_on_mouse_exited)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_pulso = fmod(_pulso + delta * 3.4, TAU)
	if _indice_seleccionado >= 0:
		queue_redraw()


func _tam_mapa() -> Vector2:
	return _textura.get_size() if _textura != null else Vector2(240, 160)


func mostrar(pois: Array[Dictionary], indice: int) -> void:
	_pois = pois.duplicate(true)
	_indice_seleccionado = indice
	if indice >= 0 and indice < _pois.size():
		var poi: Dictionary = _pois[indice]
		var posicion: Array = poi.get("tile", [0, 0])
		var tam: Array = poi.get("tile_size", [1, 1])
		_tile = Vector2i(int(posicion[0]), int(posicion[1]))
		_tile_size = Vector2i(maxi(1, int(tam[0])), maxi(1, int(tam[1])))
	queue_redraw()


func fijar_zona(tile: Vector2i, tam: Vector2i) -> void:
	_tile = tile
	_tile_size = Vector2i(maxi(1, tam.x), maxi(1, tam.y))
	queue_redraw()


## Convierte una posición del control a coordenada lógica de metadata. Devuelve
## (-1,-1) sobre la primera columna, las dos primeras filas o fuera de la grilla.
func coordenada_en(posicion: Vector2) -> Vector2i:
	var logica := posicion / float(zoom)
	var visual := Vector2i(floori(logica.x / TAM_TILE), floori(logica.y / TAM_TILE))
	var tile := visual - ORIGEN_VISUAL_TILES
	if tile.x < 0 or tile.y < 0 or tile.x >= COLUMNAS or tile.y >= FILAS:
		return Vector2i(-1, -1)
	return tile


func _indices_poi_en(tile: Vector2i) -> Array[int]:
	var resultado: Array[int] = []
	if tile.x < 0 or tile.y < 0:
		return resultado
	for i in range(_pois.size()):
		var poi: Dictionary = _pois[i]
		var posicion: Array = poi.get("tile", [0, 0])
		var tam: Array = poi.get("tile_size", [1, 1])
		var rect := Rect2i(Vector2i(int(posicion[0]), int(posicion[1])), Vector2i(maxi(1, int(tam[0])), maxi(1, int(tam[1]))))
		if rect.has_point(tile):
			resultado.append(i)
	return resultado


func _actualizar_hover(posicion: Vector2) -> void:
	var nueva := coordenada_en(posicion)
	if nueva == _tile_hover:
		return
	_tile_hover = nueva
	var hits := _indices_poi_en(_tile_hover)
	cursor_tile_cambiado.emit(_tile_hover, _tile_hover.x >= 0, hits.size())
	if modo == MODO_SELECCIONAR:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hits.is_empty() else Control.CURSOR_ARROW
	queue_redraw()


func _on_mouse_exited() -> void:
	_tile_hover = Vector2i(-1, -1)
	cursor_tile_cambiado.emit(_tile_hover, false, 0)
	queue_redraw()


func _actualizar_desde_arrastre() -> void:
	var inicio := Vector2i(mini(_origen_arrastre.x, _actual_arrastre.x), mini(_origen_arrastre.y, _actual_arrastre.y))
	var fin := Vector2i(maxi(_origen_arrastre.x, _actual_arrastre.x), maxi(_origen_arrastre.y, _actual_arrastre.y))
	_tile = inicio
	_tile_size = fin - inicio + Vector2i.ONE
	queue_redraw()


func _gui_input(evento: InputEvent) -> void:
	if not editable:
		return
	var boton := evento as InputEventMouseButton
	if boton != null and boton.button_index == MOUSE_BUTTON_LEFT:
		var celda := coordenada_en(boton.position)
		if celda.x < 0:
			_arrastrando = false
			accept_event()
			return
		if modo == MODO_SELECCIONAR:
			if boton.pressed:
				grab_focus()
				var hits := _indices_poi_en(celda)
				if not hits.is_empty():
					# Clics sucesivos permiten recorrer POI superpuestos.
					if celda != _ultima_celda_seleccion or not hits.has(_ultimo_hit):
						_ultimo_hit = hits[0]
					else:
						_ultimo_hit = hits[(hits.find(_ultimo_hit) + 1) % hits.size()]
					_ultima_celda_seleccion = celda
					poi_seleccionado.emit(_ultimo_hit)
			accept_event()
			return
		if boton.pressed:
			grab_focus()
			_arrastrando = true
			_origen_arrastre = celda
			_actual_arrastre = _origen_arrastre
			_actualizar_desde_arrastre()
		else:
			if _arrastrando:
				_actual_arrastre = celda
				_actualizar_desde_arrastre()
				_arrastrando = false
				zona_cambiada.emit(_tile, _tile_size)
		accept_event()
		return
	var movimiento := evento as InputEventMouseMotion
	if movimiento != null:
		_actualizar_hover(movimiento.position)
		if _arrastrando and modo == MODO_EDITAR:
			var celda_movimiento := coordenada_en(movimiento.position)
			if celda_movimiento.x >= 0:
				_actual_arrastre = celda_movimiento
				_actualizar_desde_arrastre()
			accept_event()


func _draw() -> void:
	var k := float(zoom)
	if _textura != null:
		draw_texture_rect(_textura, Rect2(Vector2.ZERO, _textura.get_size() * k), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, _tam_mapa() * k), Color(0.08, 0.09, 0.12))
	_dibujar_margenes_no_seleccionables()
	for i in range(_pois.size()):
		if i == _indice_seleccionado:
			continue
		var poi: Dictionary = _pois[i]
		var posicion: Array = poi.get("tile", [0, 0])
		var tam: Array = poi.get("tile_size", [1, 1])
		_dibujar_zona(Vector2i(int(posicion[0]), int(posicion[1])), Vector2i(int(tam[0]), int(tam[1])), COLOR_OTRO, false)
	if _indice_seleccionado >= 0:
		_dibujar_zona(_tile, _tile_size, COLOR_SELECCION, true)
	if _tile_hover.x >= 0:
		var hover_rect := _rect_zona(_tile_hover, Vector2i.ONE)
		draw_rect(hover_rect, Color(1, 1, 1, 0.14), false, 1.0)
	# Rejilla útil limitada al área navegable que usa region_hoenn.gd.
	var color_rejilla := Color(1, 1, 1, 0.13)
	var origen_px := Vector2(ORIGEN_VISUAL_TILES * TAM_TILE) * k
	for x in range(COLUMNAS + 1):
		draw_line(origen_px + Vector2(x * TAM_TILE * k, 0), origen_px + Vector2(x * TAM_TILE * k, FILAS * TAM_TILE * k), color_rejilla)
	for y in range(FILAS + 1):
		draw_line(origen_px + Vector2(0, y * TAM_TILE * k), origen_px + Vector2(COLUMNAS * TAM_TILE * k, y * TAM_TILE * k), color_rejilla)


func _rect_zona(tile: Vector2i, tam: Vector2i) -> Rect2:
	var k := float(zoom)
	var visual := tile + ORIGEN_VISUAL_TILES
	return Rect2(Vector2(visual * TAM_TILE) * k, Vector2(tam.max(Vector2i.ONE) * TAM_TILE) * k)


func _dibujar_zona(tile: Vector2i, tam: Vector2i, color: Color, seleccionada: bool) -> void:
	var rect := _rect_zona(tile, tam)
	draw_rect(rect, color)
	if not seleccionada:
		draw_rect(rect, color.lightened(0.45), false, 1.0)
		return
	# Halo pulsante: varios contornos crecen y cambian de intensidad sin ocultar
	# el mapa. El borde interior permanece sólido para no depender de la fase.
	var fase := (sin(_pulso) + 1.0) * 0.5
	var halo := Color(1.0, 0.82, 0.18, 0.20 + fase * 0.38)
	for expansion in range(1, 4):
		var expandido := rect.grow(float(expansion * zoom))
		draw_rect(expandido, Color(halo.r, halo.g, halo.b, halo.a / float(expansion)), false, float(zoom))
	draw_rect(rect, COLOR_BORDE, false, 2.0 + fase * 2.0)


func _dibujar_margenes_no_seleccionables() -> void:
	var k := float(zoom)
	var tam_mapa := _tam_mapa() * k
	var origen := Vector2(ORIGEN_VISUAL_TILES * TAM_TILE) * k
	var fin := origen + Vector2(COLUMNAS, FILAS) * TAM_TILE * k
	var sombra := Color(0.02, 0.03, 0.05, 0.34)
	# Superior (dos filas), izquierda (una columna) y sobrantes derecho/inferior.
	draw_rect(Rect2(Vector2.ZERO, Vector2(tam_mapa.x, origen.y)), sombra)
	draw_rect(Rect2(Vector2(0, origen.y), Vector2(origen.x, tam_mapa.y - origen.y)), sombra)
	if fin.x < tam_mapa.x:
		draw_rect(Rect2(Vector2(fin.x, origen.y), Vector2(tam_mapa.x - fin.x, tam_mapa.y - origen.y)), sombra)
	if fin.y < tam_mapa.y:
		draw_rect(Rect2(Vector2(origen.x, fin.y), Vector2(maxf(0.0, fin.x - origen.x), tam_mapa.y - fin.y)), sombra)
