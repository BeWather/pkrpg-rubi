@tool
class_name DisparadorEventoPorTiles
extends Node2D

## Base reutilizable para eventos automáticos del mapa. Detecta cuando el jugador
## termina un paso dentro de una zona de tiles; las subclases implementan el efecto.

signal evento_activado(id_evento: StringName)
signal zona_abandonada(id_evento: StringName)

@export var id_evento: StringName = &""
## Unión de rectángulos de tiles que forman una única zona lógica. Para casillas
## diagonales o dispersas se agregan rectángulos de 1×1; para áreas continuas se
## usan rectángulos mayores sin enumerar cada coordenada.
@export var zonas_tiles: Array[Rect2i] = [Rect2i(0, 0, 1, 1)]:
	set(valor):
		zonas_tiles = valor
		queue_redraw()
		if is_inside_tree():
			update_configuration_warnings()
@export var capa_datos: int = -1
@export var una_sola_vez: bool = false
@export var mostrar_zona_editor: bool = true

var _mapa: MapaConfiguracion = null
var _administrador: Node = null
var _estaba_dentro: bool = false
var _consumido: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_mapa = _buscar_mapa_padre()
	_administrador = get_tree().root.get_node_or_null("AdministradorMapa")
	set_process(true)


func _process(_delta: float) -> void:
	if _mapa == null or _administrador == null:
		return
	var mapa_actual: Variant = _administrador.get("mapa_actual")
	if mapa_actual != _mapa:
		_estaba_dentro = false
		return
	var jugador: Node = _administrador.get("jugador") as Node
	if jugador == null or bool(jugador.get("paso_en_curso")):
		return
	if capa_datos >= 0 and Singleton.capa_activa != capa_datos:
		_actualizar_borde(false)
		return
	var valor_celda: Variant = jugador.get("pos_celda_act")
	if not valor_celda is Vector2i:
		return
	_evaluar_celda_jugador(valor_celda as Vector2i)


func activar() -> bool:
	if _consumido and una_sola_vez:
		return false
	if _administrador == null:
		_administrador = get_tree().root.get_node_or_null("AdministradorMapa")
	if _mapa == null:
		_mapa = _buscar_mapa_padre()
	var aceptado := _ejecutar_evento()
	if aceptado:
		_consumido = true
		evento_activado.emit(id_evento)
	return aceptado


func reiniciar() -> void:
	_consumido = false
	_estaba_dentro = false


## Punto de extensión. El disparador base es útil por su señal; las subclases
## pueden ejecutar una acción concreta y devolver si fue aceptada.
func _ejecutar_evento() -> bool:
	return true


## Punto de extensión opcional para eventos que reaccionan al abandonar una zona.
func _al_abandonar_zona() -> void:
	pass


## Punto de extensión: evalúa la celda donde el jugador terminó su paso. Por
## defecto detecta entrada/salida de `zonas_tiles`; las subclases con varias zonas
## o lógica por estado pueden reemplazarlo.
func _evaluar_celda_jugador(celda: Vector2i) -> void:
	_actualizar_borde(_contiene_celda(celda))


func _actualizar_borde(esta_dentro: bool) -> void:
	if esta_dentro and not _estaba_dentro:
		activar()
	elif not esta_dentro and _estaba_dentro:
		_al_abandonar_zona()
		zona_abandonada.emit(id_evento)
	_estaba_dentro = esta_dentro


func _buscar_mapa_padre() -> MapaConfiguracion:
	var nodo: Node = get_parent()
	while nodo != null:
		if nodo is MapaConfiguracion:
			return nodo as MapaConfiguracion
		nodo = nodo.get_parent()
	return null


func _contiene_celda(celda: Vector2i) -> bool:
	for zona: Rect2i in zonas_tiles:
		if zona.has_point(celda):
			return true
	return false


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if zonas_tiles.is_empty():
		avisos.append("Zonas Tiles está vacío: el evento nunca se activará.")
	for indice: int in zonas_tiles.size():
		var zona: Rect2i = zonas_tiles[indice]
		if zona.size.x <= 0 or zona.size.y <= 0:
			avisos.append("Zonas Tiles[%d] debe tener ancho y alto mayores que cero." % indice)
	return avisos


func _draw() -> void:
	if not Engine.is_editor_hint() or not mostrar_zona_editor:
		return
	for zona: Rect2i in zonas_tiles:
		if zona.size.x <= 0 or zona.size.y <= 0:
			continue
		var rect := Rect2(
			Vector2(zona.position) * ConstantesGba.TAMANO_TILE,
			Vector2(zona.size) * ConstantesGba.TAMANO_TILE
		)
		draw_rect(rect, Color(0.75, 0.25, 0.85, 0.2), true)
		draw_rect(rect, Color(0.9, 0.35, 1.0, 0.9), false, 1.0)
