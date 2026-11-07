@tool
extends RefCounted

## Dibujo retenido de las banderas de un TPTileDataMap en el lienzo 2D del editor.
##
## En vez de redibujar cada celda en el overlay en cada frame, las banderas se
## vuelcan una sola vez a canvas items propios del RenderingServer (en espacio de
## mundo), troceados en bloques de CELDAS_POR_BLOQUE² celdas. Pan y zoom no cuestan
## CPU (el GPU aplica la transformación del lienzo), los bloques fuera de pantalla
## se descartan solos y al pintar solo se rehacen los bloques tocados.
## Historial de patrones probados: PATRONES_DIBUJO_BANDERAS.md (patrón B).

const CELDAS_POR_BLOQUE: int = 16
const ALFA_RELLENO: float = 0.45
const ALFA_BORDE: float = 0.85

var _capa: TPTileDataMap = null
var _raiz: RID = RID()
var _bloques: Dictionary = {}  # Vector2i -> RID del canvas item del bloque
var _bloques_sucios: Dictionary = {}  # Vector2i -> true
var _todo_sucio: bool = true
var _visible: bool = false
## Referencia (is_same) y tamaño del tile_data ya dibujado: detectan deshacer/rehacer,
## recarga de escena y cambios externos que añaden o quitan celdas.
var _datos_dibujados: Dictionary = {}
var _claves_dibujadas: int = -1
var _xform_capa: Transform2D = Transform2D()
var _mascara_filtro: int = 0  # 0 = sin filtro
## [mascara: int, relleno: Color, borde: Color] en el orden de la configuración.
var _banderas: Array = []
## flags -> Array de [relleno, borde] (una franja por bandera activa). Memo por valor.
var _franjas_por_flags: Dictionary = {}


## Cambia la capa dibujada. Libera los bloques de la anterior.
func asignar_capa(capa: TPTileDataMap) -> void:
	if capa == _capa and _raiz.is_valid():
		return
	liberar()
	_capa = capa
	if _capa == null:
		return
	_raiz = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_raiz, _capa.get_canvas_item())
	# Por encima de cualquier capa del mapa (como el overlay), sin depender del z del nodo.
	RenderingServer.canvas_item_set_z_as_relative_to_parent(_raiz, false)
	RenderingServer.canvas_item_set_z_index(_raiz, RenderingServer.CANVAS_ITEM_Z_MAX)
	RenderingServer.canvas_item_set_visible(_raiz, _visible)
	_xform_capa = Transform2D()
	_actualizar_transformacion()
	_todo_sucio = true


## Colores y orden de las banderas (lista `flags` de la config del plugin).
func configurar_banderas(flags: Array) -> void:
	_banderas.clear()
	for flag in flags:
		var base := Color(flag.color)
		var relleno := base
		relleno.a = ALFA_RELLENO
		var borde := base.lightened(0.7)
		borde.a = ALFA_BORDE
		_banderas.append([1 << int(flag.bit_index), relleno, borde])
	_franjas_por_flags.clear()
	_todo_sucio = true


## Solo dibuja las celdas con alguna bandera de `mascara` (0 = todas).
func filtrar(mascara: int) -> void:
	if mascara != _mascara_filtro:
		_mascara_filtro = mascara
		_todo_sucio = true


func set_visible(valor: bool) -> void:
	_visible = valor
	if _raiz.is_valid():
		RenderingServer.canvas_item_set_visible(_raiz, valor)


## El llamador acaba de escribir la celda `clave` ("x,y") en tile_data in situ.
## Solo se rehará su bloque; el estado actual de tile_data se da por visto.
func marcar_celda(clave: String) -> void:
	var partes := clave.split(",")
	if partes.size() != 2:
		return
	_bloques_sucios[_bloque_de(Vector2i(int(partes[0]), int(partes[1])))] = true
	adoptar_datos()


## Da por dibujado el tile_data actual (p. ej. tras confirmar un trazo cuyo
## contenido ya se fue marcando celda a celda).
func adoptar_datos() -> void:
	if _capa != null:
		_datos_dibujados = _capa.tile_data
		_claves_dibujadas = _capa.tile_data.size()


func invalidar() -> void:
	_todo_sucio = true


## Llamar una vez por frame. Rehace lo pendiente; devuelve true si redibujó algo.
func actualizar() -> bool:
	if _capa == null:
		return false
	if not is_instance_valid(_capa):
		_capa = null
		liberar()
		return false
	_actualizar_transformacion()
	if not is_same(_capa.tile_data, _datos_dibujados) or _capa.tile_data.size() != _claves_dibujadas:
		_todo_sucio = true
	if _todo_sucio:
		_reconstruir_todo()
		return true
	if _bloques_sucios.is_empty():
		return false
	for bloque: Vector2i in _bloques_sucios:
		_dibujar_bloque(bloque, _celdas_de_bloque(bloque))
	_bloques_sucios.clear()
	return true


func liberar() -> void:
	for rid: RID in _bloques.values():
		RenderingServer.free_rid(rid)
	_bloques.clear()
	_bloques_sucios.clear()
	if _raiz.is_valid():
		RenderingServer.free_rid(_raiz)
	_raiz = RID()
	_datos_dibujados = {}
	_claves_dibujadas = -1
	_todo_sucio = true


# ------------------------------------------------------------

## Las celdas se dibujan en coordenadas de mundo (celda * tile_size), igual que
## el overlay anterior: la raíz anula la transformación global del nodo.
func _actualizar_transformacion() -> void:
	var xform := _capa.get_global_transform()
	if xform != _xform_capa:
		_xform_capa = xform
		RenderingServer.canvas_item_set_transform(_raiz, xform.affine_inverse())


func _bloque_de(celda: Vector2i) -> Vector2i:
	return Vector2i(floori(celda.x / float(CELDAS_POR_BLOQUE)), floori(celda.y / float(CELDAS_POR_BLOQUE)))


func _reconstruir_todo() -> void:
	var por_bloque: Dictionary = {}  # Vector2i -> Array de [Vector2i, int]
	for clave in _capa.tile_data:
		var flags: int = _capa.tile_data[clave].get("flags", 0)
		if flags == 0:
			continue
		var partes := (clave as String).split(",")
		if partes.size() != 2:
			continue
		var celda := Vector2i(int(partes[0]), int(partes[1]))
		var bloque := _bloque_de(celda)
		if not por_bloque.has(bloque):
			por_bloque[bloque] = []
		por_bloque[bloque].append([celda, flags])
	for bloque: Vector2i in _bloques.keys():
		if not por_bloque.has(bloque):
			_dibujar_bloque(bloque, [])
	for bloque: Vector2i in por_bloque:
		_dibujar_bloque(bloque, por_bloque[bloque])
	_bloques_sucios.clear()
	_todo_sucio = false
	adoptar_datos()


func _celdas_de_bloque(bloque: Vector2i) -> Array:
	var celdas: Array = []
	var origen := bloque * CELDAS_POR_BLOQUE
	for y in range(origen.y, origen.y + CELDAS_POR_BLOQUE):
		for x in range(origen.x, origen.x + CELDAS_POR_BLOQUE):
			var datos = _capa.tile_data.get("%d,%d" % [x, y])
			if datos == null:
				continue
			var flags: int = datos.get("flags", 0)
			if flags != 0:
				celdas.append([Vector2i(x, y), flags])
	return celdas


func _franjas_de(flags: int) -> Array:
	if _franjas_por_flags.has(flags):
		return _franjas_por_flags[flags]
	var franjas: Array = []
	for bandera: Array in _banderas:
		if flags & bandera[0]:
			franjas.append([bandera[1], bandera[2]])
	_franjas_por_flags[flags] = franjas
	return franjas


## Rehace un bloque: todos los rellenos en un único triangle array y todos los
## bordes en un único multiline (un color por vértice / por segmento).
func _dibujar_bloque(bloque: Vector2i, celdas: Array) -> void:
	var rid: RID = _bloques.get(bloque, RID())
	var puntos := PackedVector2Array()
	var colores := PackedColorArray()
	var indices := PackedInt32Array()
	var lineas := PackedVector2Array()
	var colores_lineas := PackedColorArray()
	var lado := float(_capa.tile_size)
	for celda_flags: Array in celdas:
		var flags: int = celda_flags[1]
		if _mascara_filtro != 0:
			flags &= _mascara_filtro
		var franjas := _franjas_de(flags)
		if franjas.is_empty():
			continue
		var alto := lado / franjas.size()
		var origen := Vector2(celda_flags[0]) * lado
		for i in franjas.size():
			var a := origen + Vector2(0.0, alto * i)
			var b := a + Vector2(lado, 0.0)
			var c := a + Vector2(lado, alto)
			var d := a + Vector2(0.0, alto)
			var base := puntos.size()
			puntos.append(a)
			puntos.append(b)
			puntos.append(c)
			puntos.append(d)
			var relleno: Color = franjas[i][0]
			for _v in 4:
				colores.append(relleno)
			for k: int in [0, 1, 2, 0, 2, 3]:
				indices.append(base + k)
			for p: Vector2 in [a, b, b, c, c, d, d, a]:
				lineas.append(p)
			var borde: Color = franjas[i][1]
			for _s in 4:
				colores_lineas.append(borde)
	if puntos.is_empty():
		if rid.is_valid():
			RenderingServer.free_rid(rid)
			_bloques.erase(bloque)
		return
	if not rid.is_valid():
		rid = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(rid, _raiz)
		_bloques[bloque] = rid
	RenderingServer.canvas_item_clear(rid)
	RenderingServer.canvas_item_add_triangle_array(rid, indices, puntos, colores)
	# Ancho negativo: línea de 1 px de pantalla a cualquier zoom, como el overlay anterior.
	RenderingServer.canvas_item_add_multiline(rid, lineas, colores_lineas, -1.0)
