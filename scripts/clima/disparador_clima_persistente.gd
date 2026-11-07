@tool
class_name DisparadorClimaPersistente
extends "res://scripts/clima/disparador_clima_por_tiles.gd"

## Base de los eventos de clima con estado guardado en la partida (tormenta de
## arena, ceniza volcánica...). Pisar la zona de activación inicia el clima
## objetivo y pisar la de desactivación restaura el clima del mapa. El estado se
## guarda como bandera con clave `id_evento`. AdministradorMapa lo reaplica al
## cargar la partida o volver de un interior del mapa, y lo reinicia a inactivo
## cuando el jugador llega desde otro mapa. Si esa llegada es un warp que deja al
## jugador dentro de `zona_tiles_llegada`, el clima arranca activo sin transición.
##
## Las fachadas fijan en `_init()` el clima, la transición y la música, y ocultan
## esas propiedades con su propia lista `PROPIEDADES_FIJAS`.

const GRUPO_ESTADO_PERSISTENTE := &"clima_estado_persistente"
const COLOR_ACTIVACION := Color(1.0, 0.6, 0.1)
const COLOR_DESACTIVACION := Color(0.2, 0.65, 1.0)
const COLOR_LLEGADA := Color(0.3, 0.85, 0.3)
## Propiedades heredadas que nunca se usan en un clima persistente: ni se
## muestran ni se guardan.
const PROPIEDADES_FIJAS_BASE: Array[StringName] = [
	&"accion_clima",
	&"intensidad",
	&"restaurar_al_salir",
	&"zonas_tiles",
	&"capa_datos",
	&"una_sola_vez",
	&"mostrar_zona_editor",
]

@export var zona_tiles_activacion: Array[Rect2i] = []:
	set(valor):
		zona_tiles_activacion = valor
		_al_cambiar_zonas()
@export var zona_tiles_desactivacion: Array[Rect2i] = []:
	set(valor):
		zona_tiles_desactivacion = valor
		_al_cambiar_zonas()
## Si el jugador llega al mapa por un warp y aparece dentro de esta zona, el
## clima arranca activo sin transición.
@export var zona_tiles_llegada: Array[Rect2i] = []:
	set(valor):
		zona_tiles_llegada = valor
		_al_cambiar_zonas()
## Tema que suena mientras el clima está activo. "" = sin música propia: suena
## la del mapa.
@export var tema_musica: String = ""

## Objeto con `get_flag(String) -> bool` y `set_flag(String, bool)`. Si es null se
## usa el autoload SistemaGuardado. Los tests inyectan un doble.
var almacen_estado: Object = null

var _activa_en_memoria: bool = false
## Marcada por `reiniciar_estado()`: la próxima `evaluar_llegada()` decide si el
## clima arranca activo. El primer paso evaluado por el poll también la borra.
var _llegada_pendiente: bool = false


func _init() -> void:
	accion_clima = AccionClima.CAMBIAR
	intensidad = -1.0
	restaurar_al_salir = false
	zonas_tiles = []
	capa_datos = -1
	una_sola_vez = false
	mostrar_zona_editor = true


func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		add_to_group(GRUPO_ESTADO_PERSISTENTE)


func _validate_property(property: Dictionary) -> void:
	if StringName(property.name) in PROPIEDADES_FIJAS_BASE:
		property.usage = PROPERTY_USAGE_NONE


## Tema que debe sonar en el lugar mientras el clima está activo; "" si no.
func obtener_tema_musica_activo() -> String:
	return tema_musica if esta_activa() else ""


func esta_activa() -> bool:
	var almacen := _obtener_almacen()
	if almacen != null:
		return bool(almacen.call("get_flag", String(id_evento)))
	return _activa_en_memoria


func tiene_llegada_pendiente() -> bool:
	return _llegada_pendiente


## Inicia el clima con transición y lo marca activo si el administrador acepta.
func _ejecutar_evento() -> bool:
	var aceptado := super._ejecutar_evento()
	if aceptado:
		_guardar_estado(true)
		_actualizar_musica_lugar()
	return aceptado


## Restaura el clima del mapa con transición y marca el clima inactivo.
func desactivar() -> bool:
	if _administrador == null or _administrador.get("mapa_actual") != _mapa:
		return false
	if not _administrador.has_method("restaurar_clima_mapa"):
		return false
	var aceptado := bool(_administrador.call("restaurar_clima_mapa", duracion_transicion))
	if aceptado:
		_guardar_estado(false)
		_actualizar_musica_lugar()
		zona_abandonada.emit(id_evento)
	return aceptado


## Llamado por AdministradorMapa justo después de aplicar el clima inicial del
## mapa: si la partida recuerda el clima activo, lo reaplica sin transición.
func restaurar_estado_guardado() -> bool:
	_llegada_pendiente = false
	if not esta_activa() or _administrador == null:
		return false
	if not _administrador.has_method("cambiar_clima_overworld"):
		return false
	return bool(_administrador.call(
		"cambiar_clima_overworld",
		clima_objetivo,
		0.0,
		_mapa,
		intensidad
	))


## Llamado por AdministradorMapa cuando el jugador llega al mapa desde otro (vuelo,
## derrota, borde, warp): el clima queda inactivo sin transición ni cambio de
## clima, porque el administrador acaba de aplicar el clima inicial del mapa. Queda
## pendiente evaluar la celda de llegada.
func reiniciar_estado() -> void:
	_guardar_estado(false)
	_llegada_pendiente = true


## Llamado por AdministradorMapa tras el teletransporte de un warp. Si hay una
## llegada pendiente y `celda` está en `zona_tiles_llegada`, activa el clima sin
## transición. Siempre consume la marca pendiente.
func evaluar_llegada(celda: Vector2i) -> bool:
	if not _llegada_pendiente:
		return false
	_llegada_pendiente = false
	if not _zona_contiene(zona_tiles_llegada, celda):
		return false
	_guardar_estado(true)
	var aceptado := restaurar_estado_guardado()
	_actualizar_musica_lugar()
	return aceptado


func _evaluar_celda_jugador(celda: Vector2i) -> void:
	# Durante las fases de un warp el jugador sigue en la celda del mapa de
	# origen: esa celda no significa nada en este mapa.
	if _warp_en_curso():
		return
	_llegada_pendiente = false
	if _zona_contiene(zona_tiles_activacion, celda):
		if not esta_activa():
			activar()
	elif _zona_contiene(zona_tiles_desactivacion, celda):
		if esta_activa():
			desactivar()


func _warp_en_curso() -> bool:
	if _administrador == null:
		return false
	var fase: Variant = _administrador.get("coneccion")
	return fase is int and int(fase) > 0


## Al restaurar desde la partida no hace falta: actualizar_escenario() elige la
## música después de reaplicar el clima.
func _actualizar_musica_lugar() -> void:
	if _administrador != null and _administrador.has_method("actualizar_musica_lugar"):
		_administrador.call("actualizar_musica_lugar")


func _guardar_estado(activa: bool) -> void:
	_activa_en_memoria = activa
	var almacen := _obtener_almacen()
	if almacen != null:
		almacen.call("set_flag", String(id_evento), activa)


## Sin id no hay clave única: el estado vive solo en memoria.
func _obtener_almacen() -> Object:
	if String(id_evento).is_empty():
		return null
	if almacen_estado != null:
		return almacen_estado
	if Engine.is_editor_hint() or not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("SistemaGuardado")


static func _zona_contiene(zona: Array[Rect2i], celda: Vector2i) -> bool:
	for rect: Rect2i in zona:
		if rect.has_point(celda):
			return true
	return false


static func _zonas_se_solapan(zona_a: Array[Rect2i], zona_b: Array[Rect2i]) -> bool:
	for rect: Rect2i in zona_a:
		for otro: Rect2i in zona_b:
			if rect.intersects(otro):
				return true
	return false


func _al_cambiar_zonas() -> void:
	queue_redraw()
	if is_inside_tree():
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if clima_objetivo == null:
		avisos.append("Clima Objetivo vacío: el evento persistente no tiene un preset.")
	else:
		avisos.append_array(clima_objetivo.obtener_avisos())
	if String(id_evento).is_empty():
		avisos.append("ID Evento está vacío: el estado del clima no se guardará en la partida.")
	if zona_tiles_activacion.is_empty():
		avisos.append("Zona Tiles Activacion está vacía: el clima nunca se iniciará al caminar.")
	if zona_tiles_desactivacion.is_empty():
		avisos.append("Zona Tiles Desactivacion está vacía: el clima nunca se detendrá.")
	for rect: Rect2i in zona_tiles_activacion + zona_tiles_desactivacion + zona_tiles_llegada:
		if rect.size.x <= 0 or rect.size.y <= 0:
			avisos.append("Hay rectángulos con ancho o alto cero.")
			break
	if _zonas_se_solapan(zona_tiles_activacion, zona_tiles_desactivacion):
		avisos.append("Las zonas se solapan: en el solape prevalece la activación.")
	if _zonas_se_solapan(zona_tiles_llegada, zona_tiles_desactivacion):
		avisos.append("La zona de llegada se solapa con la de desactivación: al llegar ahí el clima arrancará activo.")
	return avisos


func _draw() -> void:
	if not Engine.is_editor_hint() or not mostrar_zona_editor:
		return
	_dibujar_zona(zona_tiles_llegada, COLOR_LLEGADA)
	_dibujar_zona(zona_tiles_activacion, COLOR_ACTIVACION)
	_dibujar_zona(zona_tiles_desactivacion, COLOR_DESACTIVACION)


func _dibujar_zona(zona: Array[Rect2i], color: Color) -> void:
	for rect_tiles: Rect2i in zona:
		if rect_tiles.size.x <= 0 or rect_tiles.size.y <= 0:
			continue
		var rect := Rect2(Vector2(rect_tiles.position) * ConstantesGba.TAMANO_TILE, Vector2(rect_tiles.size) * ConstantesGba.TAMANO_TILE)
		draw_rect(rect, Color(color, 0.25), true)
		draw_rect(rect, Color(color, 0.9), false, 1.0)
