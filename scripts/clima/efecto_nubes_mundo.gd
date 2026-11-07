class_name EfectoNubesMundo
extends EfectoClimaMundoBase

## Nubes de la Ruta 120 (WEATHER_CLOUDS de pokeruby), dibujadas en espacio de
## MUNDO bajo el ancla del clima (`AnclaClimaMundo` de CapasAgua, entre las capas
## `Agua` y `Suelo` del mapa), así
## que el suelo las tapa y solo se ven reflejadas en el agua.
##
## - Tres nubes de 64×64 cuyo centro empieza en el centro de `celdas_nubes`.
## - Derivan 1 px a la izquierda cada `frames_por_pixel` frames (60 fps).
## - En el GBA la X del OAM tiene 9 bits y la Y 8 bits: cada nube se repite como
##   una rejilla infinita de periodo 512×256 px. Se dibujan todas las copias que
##   tocan el rectángulo del mapa, recortadas a él para no pintar mapas vecinos.
## - Mezcla de hardware del GBA (EVA 12 / EVB 8) con el shader `nube_clima`:
##   min(1, nube·12/16 + fondo·8/16) leyendo el fondo de la pantalla. El fundido de
##   entrada/salida (`factor_mezcla` × `intensidad` × `alfa`) interpola entre el
##   fondo y esa mezcla.
## - No se dibujan sobre las celdas ocupadas de la capa de sombra de puente del
##   mapa (agua oscura bajo los puentes; MapaConfiguracion.obtener_capa_sombra_puente(),
##   normalmente la TileMapLayer `SombraPuente` de CapasAgua): en el GBA ahí no
##   se ven las nubes.

const TEXTURA: Texture2D = preload("res://graficos/climas/nubes_clima.png")
const SHADER_MEZCLA: Shader = preload("res://UI/shaders/nube_clima.gdshader")
const LADO := 64.0
const PERIODO := Vector2(512.0, 256.0)
const TAMANO_CELDA: float = ConstantesGba.TAMANO_TILE
const FRAMES_POR_SEGUNDO: float = ConstantesGba.FPS

## Celdas del mapa (no del ancla) donde está el centro inicial de cada nube.
@export var celdas_nubes: Array[Vector2i] = [Vector2i(0, 66), Vector2i(5, 73), Vector2i(10, 78)]
## Opacidad extra sobre la mezcla GBA (1 = fiel al GBA). Se multiplica por el
## factor de crossfade y la intensidad del clima.
@export_range(0.0, 1.0, 0.01) var alfa: float = 1.0
## Peso de la nube en la mezcla (EVA del GBA / 16).
@export_range(0.0, 1.0, 0.0625) var eva: float = 12.0 / 16.0:
	set(valor):
		eva = valor
		_actualizar_material()
## Peso del fondo en la mezcla (EVB del GBA / 16).
@export_range(0.0, 1.0, 0.0625) var evb: float = 8.0 / 16.0:
	set(valor):
		evb = valor
		_actualizar_material()
## No dibujar nubes sobre las celdas ocupadas de la capa de sombra de puentes.
@export var excluir_sombra_puente: bool = true
@export_range(1, 60, 1) var frames_por_pixel: int = 2
## Rectángulo de recorte en coordenadas locales de este nodo. Si está vacío se
## toma `mapa_rect_px` del MapaConfiguracion ancestro al entrar en el árbol.
@export var rect_recorte: Rect2 = Rect2()

var _frames: float = 0.0
var _material_mezcla: ShaderMaterial = null
var _capa_sombra: TileMapLayer = null
## Celdas ocupadas de la capa de sombra (Vector2i -> true), cacheadas.
var _celdas_sombra: Dictionary = {}


func _ready() -> void:
	if not rect_recorte.has_area():
		rect_recorte = _calcular_rect_recorte_mapa()
	_actualizar_material()
	refrescar_sombra_puente()
	set_process(true)


func _exit_tree() -> void:
	_desconectar_capa_sombra()


## Crea (una vez) el ShaderMaterial de mezcla GBA y le pasa EVA/EVB.
func _actualizar_material() -> void:
	if _material_mezcla == null:
		_material_mezcla = ShaderMaterial.new()
		_material_mezcla.shader = SHADER_MEZCLA
	_material_mezcla.set_shader_parameter(&"eva", eva)
	_material_mezcla.set_shader_parameter(&"evb", evb)
	if material != _material_mezcla:
		material = _material_mezcla
	queue_redraw()


func _process(delta: float) -> void:
	_avanzar(maxf(0.0, delta) * FRAMES_POR_SEGUNDO)


## Avanza un número exacto de frames del GBA (tests y depuración).
func avanzar_frames(frames: int) -> void:
	_avanzar(float(maxi(frames, 0)))


func _avanzar(frames: float) -> void:
	var desplazamiento_previo: int = obtener_desplazamiento()
	_frames += frames
	# Mantiene el acumulador acotado: el patrón se repite cada PERIODO.x píxeles.
	var frames_periodo: float = PERIODO.x * float(frames_por_pixel)
	if _frames >= frames_periodo:
		_frames = fmod(_frames, frames_periodo)
	if obtener_desplazamiento() != desplazamiento_previo:
		queue_redraw()


## Píxeles derivados hacia la izquierda (entero, sin interpolar), módulo 512.
func obtener_desplazamiento() -> int:
	return floori(_frames / float(frames_por_pixel))


## Centro actual (sin repetir) de cada nube en coordenadas locales.
func obtener_centros_base() -> Array[Vector2]:
	var centros: Array[Vector2] = []
	var deriva := Vector2(float(obtener_desplazamiento()), 0.0)
	var origen_mapa: Vector2 = _obtener_origen_mapa_local()
	for celda: Vector2i in celdas_nubes:
		var centro: Vector2 = origen_mapa + Vector2(celda) * TAMANO_CELDA + Vector2(8.0, 8.0) - deriva
		centros.append(centro)
	return centros


## Centros de todas las copias de la rejilla 512×256 cuyo sprite toca `rect`.
func obtener_centros_en(rect: Rect2) -> Array[Vector2]:
	var centros: Array[Vector2] = []
	if not rect.has_area():
		return centros
	var medio: float = LADO * 0.5
	for base: Vector2 in obtener_centros_base():
		# Primera copia cuyo borde derecho/inferior supera el inicio del rect.
		var x_inicial: float = base.x + ceilf((rect.position.x - medio - base.x) / PERIODO.x) * PERIODO.x
		var y_inicial: float = base.y + ceilf((rect.position.y - medio - base.y) / PERIODO.y) * PERIODO.y
		var y: float = y_inicial
		while y - medio < rect.end.y:
			var x: float = x_inicial
			while x - medio < rect.end.x:
				var sprite := Rect2(Vector2(x, y) - Vector2(medio, medio), Vector2(LADO, LADO))
				if sprite.intersects(rect):
					centros.append(Vector2(x, y))
				x += PERIODO.x
			y += PERIODO.y
	return centros


## Peso de la mezcla GBA (alfa × factor de mezcla × intensidad): 0 = solo fondo,
## 1 = min(1, nube·EVA + fondo·EVB). Va al shader en el alfa del modulate.
func obtener_alfa_efectivo() -> float:
	return alfa * factor_mezcla * intensidad


## Pares [destino, región de la textura] de cada copia visible, ya recortados a
## `rect_recorte` (coordenadas locales de este nodo) y, si
## `excluir_sombra_puente`, sin las celdas ocupadas de `SombraPuente`.
func obtener_dibujos() -> Array[Rect2]:
	var dibujos: Array[Rect2] = []
	if not rect_recorte.has_area():
		return dibujos
	var medio := Vector2(LADO, LADO) * 0.5
	var excluir: bool = excluir_sombra_puente and not _celdas_sombra.is_empty()
	var origen_sombra: Vector2 = _obtener_origen_capa_sombra() if excluir else Vector2.ZERO
	for centro: Vector2 in obtener_centros_en(rect_recorte):
		var sprite := Rect2(centro - medio, Vector2(LADO, LADO))
		var visible_rect: Rect2 = sprite.intersection(rect_recorte)
		if not visible_rect.has_area():
			continue
		var region := Rect2(visible_rect.position - sprite.position, visible_rect.size)
		if excluir:
			_anadir_sin_sombra(dibujos, visible_rect, region, origen_sombra)
		else:
			dibujos.append(visible_rect)
			dibujos.append(region)
	return dibujos


## Trocea `destino` en franjas por fila de celdas de 16×16 y añade solo los
## tramos horizontales de celdas libres (sin tile en SombraPuente).
func _anadir_sin_sombra(dibujos: Array[Rect2], destino: Rect2, region: Rect2, origen: Vector2) -> void:
	var fila_ini: int = floori((destino.position.y - origen.y) / TAMANO_CELDA)
	var fila_fin: int = ceili((destino.end.y - origen.y) / TAMANO_CELDA) - 1
	var col_ini: int = floori((destino.position.x - origen.x) / TAMANO_CELDA)
	var col_fin: int = ceili((destino.end.x - origen.x) / TAMANO_CELDA) - 1
	for fila: int in range(fila_ini, fila_fin + 1):
		var y0: float = maxf(destino.position.y, origen.y + fila * TAMANO_CELDA)
		var y1: float = minf(destino.end.y, origen.y + (fila + 1) * TAMANO_CELDA)
		if y1 <= y0:
			continue
		var tramo_ini: int = -1
		for col: int in range(col_ini, col_fin + 2):
			var libre: bool = col <= col_fin and not _celdas_sombra.has(Vector2i(col, fila))
			if libre and tramo_ini < 0:
				tramo_ini = col
			elif not libre and tramo_ini >= 0:
				var x0: float = maxf(destino.position.x, origen.x + tramo_ini * TAMANO_CELDA)
				var x1: float = minf(destino.end.x, origen.x + col * TAMANO_CELDA)
				if x1 > x0:
					var trozo := Rect2(x0, y0, x1 - x0, y1 - y0)
					dibujos.append(trozo)
					dibujos.append(Rect2(region.position + trozo.position - destino.position, trozo.size))
				tramo_ini = -1


## Relee las celdas ocupadas de la capa de sombra del mapa (se llama al entrar
## en el árbol y cada vez que la capa emite `changed`).
func refrescar_sombra_puente() -> void:
	var capa: TileMapLayer = _buscar_capa_sombra()
	if capa != _capa_sombra:
		_desconectar_capa_sombra()
		_capa_sombra = capa
		if _capa_sombra != null and not _capa_sombra.changed.is_connected(_on_capa_sombra_cambiada):
			_capa_sombra.changed.connect(_on_capa_sombra_cambiada)
	_celdas_sombra.clear()
	if _capa_sombra != null:
		for celda: Vector2i in _capa_sombra.get_used_cells():
			_celdas_sombra[celda] = true
	queue_redraw()


## Celdas de sombra cacheadas (tests y depuración).
func obtener_celdas_sombra() -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	for celda: Variant in _celdas_sombra.keys():
		celdas.append(celda as Vector2i)
	return celdas


func _on_capa_sombra_cambiada() -> void:
	refrescar_sombra_puente()


func _desconectar_capa_sombra() -> void:
	if _capa_sombra == null or not is_instance_valid(_capa_sombra):
		return
	if _capa_sombra.changed.is_connected(_on_capa_sombra_cambiada):
		_capa_sombra.changed.disconnect(_on_capa_sombra_cambiada)


## Capa de sombra de puente del mapa ancestro (fuente única: su CapasAgua, o el
## nodo `SombraPuente` en mapas sin migrar).
func _buscar_capa_sombra() -> TileMapLayer:
	var mapa: MapaConfiguracion = _buscar_mapa_ancestro()
	if mapa == null:
		return null
	return mapa.obtener_capa_sombra_puente()


## Esquina de la celda (0,0) de la capa de sombra en coordenadas locales de este
## nodo (celdas de 16×16, sin rotación ni escala).
func _obtener_origen_capa_sombra() -> Vector2:
	if _capa_sombra == null or not is_instance_valid(_capa_sombra):
		return _obtener_origen_mapa_local()
	if not _capa_sombra.is_inside_tree() or not is_inside_tree():
		return _obtener_origen_mapa_local()
	return to_local(_capa_sombra.global_position)


func _draw() -> void:
	var alfa_efectivo: float = obtener_alfa_efectivo()
	if alfa_efectivo <= 0.0:
		return
	var modulacion := Color(1.0, 1.0, 1.0, alfa_efectivo)
	var dibujos: Array[Rect2] = obtener_dibujos()
	for indice: int in range(0, dibujos.size(), 2):
		draw_texture_rect_region(TEXTURA, dibujos[indice], dibujos[indice + 1], modulacion)


func _calcular_rect_recorte_mapa() -> Rect2:
	var mapa: MapaConfiguracion = _buscar_mapa_ancestro()
	if mapa == null or not mapa.mapa_rect_px.has_area():
		return Rect2()
	var origen: Vector2 = _obtener_origen_mapa_local()
	return Rect2(origen + mapa.mapa_rect_px.position, mapa.mapa_rect_px.size)


## Origen (esquina superior izquierda, celda 0,0) del mapa en coordenadas locales
## de este nodo. Con el ancla en (0,0) del mapa es (0,0).
func _obtener_origen_mapa_local() -> Vector2:
	var mapa: MapaConfiguracion = _buscar_mapa_ancestro()
	if mapa == null or not is_inside_tree():
		return Vector2.ZERO
	return to_local(mapa.global_position)


func _buscar_mapa_ancestro() -> MapaConfiguracion:
	var nodo: Node = get_parent()
	while nodo != null:
		if nodo is MapaConfiguracion:
			return nodo as MapaConfiguracion
		nodo = nodo.get_parent()
	return null
