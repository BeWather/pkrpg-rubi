@tool
class_name DisparadorTierraPies
extends "res://scripts/eventos/disparador_evento_por_tiles.gd"

## Muestra tierra en los pies del jugador mientras pisa la zona. A diferencia del
## disparador base, también evalúa durante el paso: la tierra se ve con el jugador
## quieto en la zona, en la primera mitad de un paso que sale de ella y en la
## segunda mitad de un paso que entra. Solo avisa al jugador cuando cambia.
##
## En el editor cubre cada rectángulo con un sprite interno (no se guarda en la
## escena) para que el nodo se pueda seleccionar haciendo clic en el lienzo.

const METODO_JUGADOR := &"mostrar_tierra_pies"
const COLOR_ZONA := Color(0.8, 0.55, 0.25)
const NOMBRE_SELECCION := "SeleccionEditor"
## Propiedades heredadas sin sentido para este evento: ni se muestran ni se guardan.
const PROPIEDADES_FIJAS: Array[StringName] = [&"una_sola_vez"]

var _jugador_avisado: Node = null
var _mostrando: bool = false
var _zonas_seleccion: Array[Rect2i] = []


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		_sincronizar_seleccion()


func _exit_tree() -> void:
	_avisar_jugador(null, false)


func _validate_property(property: Dictionary) -> void:
	if StringName(property.name) in PROPIEDADES_FIJAS:
		property.usage = PROPERTY_USAGE_NONE


func _process(_delta: float) -> void:
	if _mapa == null or _administrador == null:
		return
	var jugador: Node = null
	if _administrador.get("mapa_actual") == _mapa:
		jugador = _administrador.get("jugador") as Node
	_avisar_jugador(jugador, jugador != null and _jugador_sobre_zona(jugador))


## Quieto: su celda. En paso: la celda de origen hasta la mitad y la de destino
## desde la mitad (pos_celda_act sigue siendo el origen hasta terminar el paso).
func _jugador_sobre_zona(jugador: Node) -> bool:
	if capa_datos >= 0 and Singleton.capa_activa != capa_datos:
		return false
	var valor_celda: Variant = jugador.get("pos_celda_act")
	if not valor_celda is Vector2i:
		return false
	var celda := valor_celda as Vector2i
	if bool(jugador.get("paso_en_curso")) and float(jugador.get("progreso_paso")) >= 0.5:
		var direccion: Variant = jugador.get("facing_direction")
		if direccion is Vector2:
			celda += Vector2i(direccion as Vector2)
	return _contiene_celda(celda)


func _avisar_jugador(jugador: Node, mostrar: bool) -> void:
	if jugador != _jugador_avisado:
		# Otro jugador o ninguno: el anterior deja de mostrar la tierra.
		if _mostrando and is_instance_valid(_jugador_avisado):
			_jugador_avisado.call(METODO_JUGADOR, false)
		_jugador_avisado = jugador
		_mostrando = false
	if jugador == null or mostrar == _mostrando:
		return
	_mostrando = mostrar
	if jugador.has_method(METODO_JUGADOR):
		jugador.call(METODO_JUGADOR, mostrar)
	if mostrar:
		evento_activado.emit(id_evento)
	else:
		zona_abandonada.emit(id_evento)


func _sincronizar_seleccion() -> void:
	if not is_inside_tree():
		return
	var anterior := get_node_or_null(NOMBRE_SELECCION)
	if anterior != null:
		remove_child(anterior)
		anterior.queue_free()
	_zonas_seleccion = zonas_tiles.duplicate()
	# Sin owner: el editor no lo guarda y, al hacer clic sobre él, selecciona este nodo.
	var contenedor := Node2D.new()
	contenedor.name = NOMBRE_SELECCION
	add_child(contenedor)
	for zona: Rect2i in zonas_tiles:
		if zona.size.x <= 0 or zona.size.y <= 0:
			continue
		contenedor.add_child(_crear_sprite_seleccion(zona))


func _crear_sprite_seleccion(zona: Rect2i) -> Sprite2D:
	var imagen := Image.create(zona.size.x * 16, zona.size.y * 16, false, Image.FORMAT_RGBA8)
	imagen.fill(Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(imagen)
	sprite.centered = false
	sprite.position = Vector2(zona.position) * 16.0
	sprite.modulate = Color(COLOR_ZONA, 0.3)
	return sprite


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# El setter de zonas_tiles pide redibujar: se aprovecha para rehacer la selección.
	if _zonas_seleccion != zonas_tiles:
		_sincronizar_seleccion.call_deferred()
	if not mostrar_zona_editor:
		return
	for zona: Rect2i in zonas_tiles:
		if zona.size.x <= 0 or zona.size.y <= 0:
			continue
		var rect := Rect2(Vector2(zona.position) * 16.0, Vector2(zona.size) * 16.0)
		draw_rect(rect, Color(COLOR_ZONA, 0.9), false, 1.0)
