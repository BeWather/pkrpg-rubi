class_name EfectosArena
extends Sprite2D

## Efectos de arena de una entidad del overworld (jugador o NPC). El propio nodo es
## la arena que cubre los pies (`arena3.png`) sobre tiles DESIERTO; además deja
## huellas temporales al abandonar tiles DESIERTO o ARENA_HUELLA.
##
## Se añade como último hijo de la entidad para dibujarse sobre sus sprites. La
## entidad informa del inicio, progreso y fin de cada paso; este nodo no consulta
## tiles por frame.

const TEXTURA_ARENA_PIES: Texture2D = preload("res://graficos/climas/arena3.png")
const HUELLA_ARRIBA: Texture2D = preload("res://graficos/climas/huella_arena_arriba.png")
const HUELLA_IZQUIERDA: Texture2D = preload("res://graficos/climas/huella_arena_izquierda.png")
const BICI_VERTICAL: Texture2D = preload("res://graficos/climas/bici_huella_arena_vertical.png")
const BICI_HORIZONTAL: Texture2D = preload("res://graficos/climas/bici_huella_arena_horizontal.png")
const BICI_CURVA_ARRIBA: Texture2D = preload("res://graficos/climas/bici_huella_arena_curva1.png")
const BICI_CURVA_ABAJO: Texture2D = preload("res://graficos/climas/bici_huella_arena_curva2.png")

## La arena de los pies se oculta mientras el paso está entre estos píxeles.
const PIXELES_INICIO_PASO := 4.0
const PIXELES_FIN_PASO := 12.0
## El origen de las entidades está en celda·16 + (8,14): el centro del tile queda
## 6 px más arriba. La arena de los pies (16×8, centrada) cubre de -4 a +4.
const DESPLAZAMIENTO_CENTRO_TILE := Vector2(0, -6)
const POSICION_ARENA_PIES := Vector2(0, 0)

## Vida de cada huella (dt) y tramo final en el que parpadea.
var duracion_huella: float = 1.0
var duracion_parpadeo: float = 0.4

var _origen_desierto: bool = false
var _destino_desierto: bool = false
var _ultima_huella: HuellaArena = null
var _ultima_direccion: Vector2 = Vector2.ZERO
var _ultima_en_bici: bool = false


func _init() -> void:
	name = "EfectosArena"
	texture = TEXTURA_ARENA_PIES
	centered = true
	position = POSICION_ARENA_PIES
	visible = false
	set_meta(&"sin_reflejo", true)


## Llamar al empezar un paso normal, con la entidad aún en el tile de origen.
func iniciar_paso(
	tp: TPTileDataMap,
	mapa: Node,
	celda_origen: Vector2i,
	celda_destino: Vector2i,
	direccion: Vector2,
	en_bici: bool
) -> void:
	_origen_desierto = _tiene_flag(tp, celda_origen, TPTileDataMap.Flags.DESIERTO)
	_destino_desierto = _tiene_flag(tp, celda_destino, TPTileDataMap.Flags.DESIERTO)
	visible = _origen_desierto
	var deja_huella := _origen_desierto \
		or _tiene_flag(tp, celda_origen, TPTileDataMap.Flags.ARENA_HUELLA)
	var huella: HuellaArena = null
	if deja_huella:
		huella = _crear_huella(mapa, direccion, en_bici)
	# Sin huella en este tile, el próximo giro no puede enlazar una curva.
	_ultima_huella = huella
	_ultima_direccion = direccion
	_ultima_en_bici = en_bici


## `pixeles`: distancia recorrida en el paso actual (0..16).
func actualizar_progreso(pixeles: float) -> void:
	visible = (pixeles < PIXELES_INICIO_PASO and _origen_desierto) \
		or (pixeles > PIXELES_FIN_PASO and _destino_desierto)


## Entidad quieta en `celda` (fin de paso, aterrizaje, teletransporte o spawn).
func actualizar_reposo(tp: TPTileDataMap, celda: Vector2i) -> void:
	_origen_desierto = _tiene_flag(tp, celda, TPTileDataMap.Flags.DESIERTO)
	_destino_desierto = _origen_desierto
	visible = _origen_desierto


func ocultar() -> void:
	visible = false


## Sprite de huella para un paso en `direccion`. En bici, un giro perpendicular
## respecto a `direccion_previa` usa una curva si la huella previa sigue viva.
## Devuelve {"textura": Texture2D, "flip_h": bool, "flip_v": bool}.
static func resolver_huella(
	direccion: Vector2,
	en_bici: bool,
	direccion_previa: Vector2 = Vector2.ZERO,
	previa_viva: bool = false
) -> Dictionary:
	var vertical := absf(direccion.y) > absf(direccion.x)
	if en_bici:
		var perpendicular := direccion_previa != Vector2.ZERO \
			and is_zero_approx(direccion.dot(direccion_previa))
		if previa_viva and perpendicular:
			return _resolver_curva(direccion_previa, direccion)
		return _datos_huella(BICI_VERTICAL if vertical else BICI_HORIZONTAL, false, false)
	if vertical:
		return _datos_huella(HUELLA_ARRIBA, false, direccion.y > 0.0)
	return _datos_huella(HUELLA_IZQUIERDA, direccion.x > 0.0, false)


## Las curvas unen dos bordes del tile: se entra por el borde opuesto a la
## dirección previa y se sale por el de la nueva. `curva1` une arriba-derecha y
## `curva2` abajo-derecha; el espejo horizontal cambia derecha por izquierda.
static func _resolver_curva(previa: Vector2, nueva: Vector2) -> Dictionary:
	var une_arriba := nueva.y < 0.0 or previa.y > 0.0
	var une_izquierda := nueva.x < 0.0 or previa.x > 0.0
	return _datos_huella(BICI_CURVA_ARRIBA if une_arriba else BICI_CURVA_ABAJO, une_izquierda, false)


static func _datos_huella(textura: Texture2D, espejo_h: bool, espejo_v: bool) -> Dictionary:
	return {"textura": textura, "flip_h": espejo_h, "flip_v": espejo_v}


static func _tiene_flag(tp: TPTileDataMap, celda: Vector2i, flag: int) -> bool:
	return tp != null and tp.has_flag(Vector2(celda), flag)


func _crear_huella(mapa: Node, direccion: Vector2, en_bici: bool) -> HuellaArena:
	var entidad := get_parent() as Node2D
	if entidad == null:
		return null
	var contenedor: Node = null
	if mapa != null and mapa.has_method("obtener_contenedor_huellas"):
		contenedor = mapa.call("obtener_contenedor_huellas")
	if contenedor == null:
		contenedor = entidad.get_parent()
	if contenedor == null:
		return null
	var previa_viva := is_instance_valid(_ultima_huella) and _ultima_huella.esta_viva()
	var direccion_previa := _ultima_direccion if _ultima_en_bici else Vector2.ZERO
	var datos := resolver_huella(direccion, en_bici, direccion_previa, previa_viva)
	var huella := HuellaArena.new()
	huella.configurar(datos.textura, datos.flip_h, datos.flip_v, duracion_huella, duracion_parpadeo)
	contenedor.add_child(huella)
	huella.global_position = entidad.global_position + DESPLAZAMIENTO_CENTRO_TILE
	return huella
