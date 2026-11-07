class_name TierraPies
extends Sprite2D

## Tierra que levanta una entidad (jugador o NPC) al pisar tiles con la bandera
## TPTileDataMap.Flags.TIERRA_PIES, o la zona de un DisparadorTierraPies (solo
## jugador). La textura tiene dos frames de 16×16: el primero es el de reposo y el
## segundo se intercala dos veces durante cada paso (0 → 1 → 0 → 1 → 0).
##
## Se añade como último hijo de la entidad para dibujarse sobre sus sprites. La
## entidad informa del inicio, progreso y fin de cada paso, igual que con
## EfectosArena: este nodo no consulta tiles por frame. `sobre_bandera` dice si
## la bandera pide la tierra ahora; quien la gestione la combina con el resto de
## motivos (zona del evento, surf, salto) para fijar `visible`.

const TEXTURA_TIERRA_PIES: Texture2D = preload("res://graficos/character/tierra-pies.png")
## El origen de las entidades está en celda·16 + (8,14): con este offset la
## esquina superior izquierda del frame coincide con la del tile.
const OFFSET_TILE := Vector2(-8, -14)
## Tramos del paso (en píxeles recorridos, 0..16) que muestran el segundo frame.
const TRAMOS_FRAME_PASO: Array[Vector2] = [Vector2(2, 6), Vector2(10, 14)]
## Como en DisparadorTierraPies, la tierra pasa del tile de origen al de destino a
## mitad de paso (en píxeles recorridos).
const PIXELES_CAMBIO_TILE := 8.0

## La bandera TIERRA_PIES pide la tierra en el estado actual de la entidad.
var sobre_bandera: bool = false

var _origen_con_bandera: bool = false
var _destino_con_bandera: bool = false


func _init() -> void:
	name = "TierraPies"
	texture = TEXTURA_TIERRA_PIES
	hframes = 2
	frame = 0
	centered = false
	offset = OFFSET_TILE
	visible = false
	set_meta(&"sin_reflejo", true)


## Llamar al empezar un paso, con la entidad aún en el tile de origen.
func iniciar_paso(tp: TPTileDataMap, celda_origen: Vector2i, celda_destino: Vector2i) -> void:
	_origen_con_bandera = _tiene_bandera(tp, celda_origen)
	_destino_con_bandera = _tiene_bandera(tp, celda_destino)
	sobre_bandera = _origen_con_bandera


## Entidad quieta en `celda` (fin de paso, aterrizaje, teletransporte o spawn).
func actualizar_reposo(tp: TPTileDataMap, celda: Vector2i) -> void:
	_origen_con_bandera = _tiene_bandera(tp, celda)
	_destino_con_bandera = _origen_con_bandera
	sobre_bandera = _origen_con_bandera


## Sin tierra por bandera (surf, salto o NPC oculto).
func ocultar() -> void:
	_origen_con_bandera = false
	_destino_con_bandera = false
	sobre_bandera = false


## `pixeles`: distancia recorrida en el paso actual (0..16).
func actualizar_progreso(pixeles: float) -> void:
	frame = frame_para_pixeles(pixeles)
	sobre_bandera = _origen_con_bandera if pixeles < PIXELES_CAMBIO_TILE else _destino_con_bandera


func reiniciar_frame() -> void:
	frame = 0


static func frame_para_pixeles(pixeles: float) -> int:
	for tramo: Vector2 in TRAMOS_FRAME_PASO:
		if pixeles >= tramo.x and pixeles < tramo.y:
			return 1
	return 0


static func _tiene_bandera(tp: TPTileDataMap, celda: Vector2i) -> bool:
	return tp != null and tp.has_flag(Vector2(celda), TPTileDataMap.Flags.TIERRA_PIES)
