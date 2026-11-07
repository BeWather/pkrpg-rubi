## npc_abuelo_guarderia.gd
## Abuelo de la GUARDERÍA POKéMON, fuera, en la Ruta 117 (pokeruby
## Route117_EventScript_1B222D, data/scripts/day_care.inc).
##
## Según `Guarderia.obtener_estado()`:
## - 0: se presenta y remite a su mujer.
## - 1: ofrece el HUEVO; con NO insiste una vez y un segundo NO lo rechaza
##   (`rechazar_huevo`). Con SÍ y sitio en el equipo, fanfarria y el huevo de
##   `generar_huevo()` pasa al equipo.
## - 2: "Tu {mon} está bien." · 3: "Tus {mon} y {mon2} están bien." + la frase
##   de compatibilidad.
## Con un huevo pendiente espera en `celda_con_huevo` (FLAG_PENDING_DAYCARE_EGG:
## setobjectxyperm al entrar en el mapa); si no, en su celda de la escena. Se
## recoloca cuando su mapa pasa a ser el actual (`mapa_activado`).
## Diálogos como npc_artesano_vidrio.gd; textos: claves GUARDERIA_* de dialogos.csv.
@tool
extends "res://scripts/npc/npc_base.gd"

const MOTIVO_PAUSA: StringName = &"abuelo_guarderia"
const TAMANO_EQUIPO_MAXIMO: int = 6

## Celda donde espera cuando hay un huevo pendiente.
@export var celda_con_huevo: Vector2i = Vector2i(47, 6)

## Guardería usada por el guion; null = SistemaGuardado.get_guarderia().
var guarderia: Guarderia = null
## Fanfarria al recibir el huevo (MUS_FANFA1). Vacía = sin fanfarria (tests).
var tema_fanfarria: String = "LEVEL_UP"

signal _mensaje_terminado

var _secuencia_activa: bool = false
## Celda de la escena (la de siempre).
var _celda_normal: Vector2i = Vector2i.ZERO
var _texto_huevo_listo: bool = false


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_celda_normal = coord_celda
	colocar_segun_estado()


## Los exteriores siguen instanciados en el Overworld: se recoloca al volver a ser
## el mapa actual (warp, cruce de borde o carga). npc_base ya conecta
## `mapa_activado` a este método.
func _on_mapa_activado(por_warp: bool) -> void:
	super._on_mapa_activado(por_warp)
	colocar_segun_estado()


func _obtener_guarderia() -> Guarderia:
	return guarderia if guarderia != null else SistemaGuardado.get_guarderia()


## (47,6) con un huevo pendiente; si no, su celda de siempre.
func colocar_segun_estado() -> void:
	if _secuencia_activa or estado_actual == EstadoNPC.MOVING:
		return
	var con_huevo := _obtener_guarderia().obtener_estado() == Guarderia.Estado.HUEVO_PENDIENTE
	var celda := celda_con_huevo if con_huevo else _celda_normal
	if celda == coord_celda:
		return
	coord = celda
	position = Vector2(celda.x * TILE_SIZE + OFFSET.x, celda.y * TILE_SIZE + OFFSET.y)
	coord_celda = celda
	celda_origen = celda
	rango_ini = celda - rango
	rango_fin = celda + rango
	actualizar_efecto_terreno_actual()


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_ejecutar_secuencia()


func _ejecutar_secuencia() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	mirar_jugador()  # faceplayer
	_bloquear_jugador(true)

	var dc := _obtener_guarderia()
	match dc.obtener_estado():
		Guarderia.Estado.HUEVO_PENDIENTE:
			await _ofrecer_huevo(dc)
		Guarderia.Estado.UNO:
			await _mensaje("GUARDERIA_ABUELO_UNO", {"{mon}": _nombre(dc, 0)})
		Guarderia.Estado.DOS:
			await _mensaje("GUARDERIA_ABUELO_DOS", {"{mon}": _nombre(dc, 0), "{mon2}": _nombre(dc, 1)})
			await _mensaje(dc.clave_texto_compatibilidad())
		_:
			await _mensaje("GUARDERIA_ABUELO_PRESENTACION")
	_finalizar()


## Route117_EventScript_1B2262: dos oportunidades de aceptar el huevo.
func _ofrecer_huevo(dc: Guarderia) -> void:
	var acepta: bool = await _preguntar("GUARDERIA_ABUELO_HUEVO")
	if not acepta:
		acepta = await _preguntar("GUARDERIA_ABUELO_HUEVO_INSISTE")
	if not acepta:
		await _mensaje("GUARDERIA_ABUELO_ME_LO_QUEDO")
		dc.rechazar_huevo()  # RejectEggFromDayCare
		return
	var equipo: Array = SistemaGuardado.get_equipo()
	if equipo.size() >= TAMANO_EQUIPO_MAXIMO:
		await _mensaje("GUARDERIA_ABUELO_SIN_SITIO")
		return
	# message + playfanfare MUS_FANFA1 + waitfanfare + waitbuttonpress.
	_texto_huevo_listo = false
	continuar_dialogo(texto("GUARDERIA_ABUELO_RECIBE_HUEVO"), true, _marcar_texto_huevo_listo)
	if not tema_fanfarria.is_empty():
		await reproducir_fanfarria(tema_fanfarria)
	if not _texto_huevo_listo:
		await _mensaje_terminado
	await _mensaje("GUARDERIA_ABUELO_CUIDALO")
	var huevo := dc.generar_huevo()  # GiveEggFromDaycare
	if huevo == null:
		push_warning("[AbueloGuarderia] No se pudo generar el huevo")
		return
	equipo.append(huevo)


func _marcar_texto_huevo_listo() -> void:
	_texto_huevo_listo = true
	_mensaje_terminado.emit()


func _nombre(dc: Guarderia, i: int) -> String:
	var poke := dc.obtener_pokemon(i)
	return poke.get_nombre_mostrar() if poke != null else ""


func _finalizar() -> void:
	if nodo_administrador and is_instance_valid(nodo_administrador.cuadro_dialogo):
		nodo_administrador.cuadro_dialogo.cerrar()
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


func _bloquear_jugador(activo: bool) -> void:
	Singleton.mantener_pausa(MOTIVO_PAUSA, activo)
	if jugador == null:
		return
	if activo:
		jugador.start_dialog()
	else:
		jugador.end_dialog()
	jugador.no_control = activo


func _exit_tree() -> void:
	if _secuencia_activa and not Engine.is_editor_hint():
		Singleton.mantener_pausa(MOTIVO_PAUSA, false)


# ==============================================
# DIÁLOGOS
# ==============================================

## Texto de la clave `clave` con las sustituciones {mon}, {mon2}, {n}.
static func texto(clave: String, sustituciones: Dictionary = {}) -> String:
	var resultado := TranslationServer.translate(clave)
	for marca in sustituciones:
		resultado = resultado.replace(str(marca), str(sustituciones[marca]))
	return resultado


## Espera el botón y deja el cuadro abierto para el siguiente mensaje.
func _mensaje(clave: String, sustituciones: Dictionary = {}) -> void:
	continuar_dialogo(texto(clave, sustituciones), true, _mensaje_terminado.emit)
	await _mensaje_terminado


func _preguntar(clave: String, sustituciones: Dictionary = {}) -> bool:
	var dialogo = nodo_administrador.cuadro_dialogo
	# preguntaSiNo() exige IDLE: cerrar() y reabrir en el mismo frame no se ve.
	var continua: bool = dialogo.esta_activo
	dialogo.cerrar()
	dialogo.omitir_siguiente_sonido_inicio = continua
	dialogo.preguntaSiNo(texto(clave, sustituciones))
	while true:
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			return not parametros.is_empty() and str(parametros[0]) == "Y"
	return false
