## npc_cinta_esfuerzo.gd
## Mujer de la CINTA ESFUERZO de CIUDAD PORTUAL
## (SlateportCity_EventScript_EffortRibbonWoman). Mira al primer Pokémon del
## equipo que no sea un HUEVO (GetLeadMonIndex):
## - ya tiene la cinta → `texto_ya_tiene`;
## - suma de EV < 510 (ScrSpecial_AreLeadMonEVsMaxedOut) → `texto_esfuerzate`;
## - si no → `texto_entrega`, "{PN} recibió la CINTA ESFUERZO." con la fanfarria
##   de objeto, `texto_puesta` y añade la cinta (GivLeadMonEffortRibbon).
## {especie} es el nombre de la especie, no el mote (bufferleadmonspeciesname).
## Diálogos y bloqueo del jugador: patrón de npc_regalo_diario.gd.
@tool
extends "res://scripts/npc/npc_base.gd"

const MOTIVO_PAUSA: StringName = &"cinta_esfuerzo"
const CINTA: String = "ESFUERZO"
const EV_MAXIMOS: int = 510

@export var texto_tu_pokemon: String = "PORTUAL_CINTA_TU_POKEMON"
@export var texto_ya_tiene: String = "PORTUAL_CINTA_YA_TIENE"
@export var texto_esfuerzate: String = "PORTUAL_CINTA_ESFUERZATE"
@export var texto_entrega: String = "PORTUAL_CINTA_ENTREGA"
@export var texto_recibida: String = "PORTUAL_CINTA_RECIBIDA"
@export var texto_puesta: String = "PORTUAL_CINTA_PUESTA"

signal _mensaje_terminado

var _secuencia_activa: bool = false
var _texto_recibida_listo: bool = false


## GetLeadMonIndex: primer Pokémon que no es un HUEVO (o el primero si todos lo son).
static func pokemon_lider(equipo: Array) -> BasePokemon:
	for pokemon in equipo:
		if pokemon is BasePokemon and not pokemon.huevo:
			return pokemon
	return equipo[0] if not equipo.is_empty() and equipo[0] is BasePokemon else null


static func suma_ev(pokemon: BasePokemon) -> int:
	return pokemon.ev_ps + pokemon.ev_ataque + pokemon.ev_defensa \
		+ pokemon.ev_ataque_especial + pokemon.ev_defensa_especial + pokemon.ev_velocidad


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	var lider := pokemon_lider(SistemaGuardado.get_equipo())
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null or lider == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_ejecutar_secuencia(lider)


func _ejecutar_secuencia(lider: BasePokemon) -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	if tipo_movimiento != TipoMovimientoNPC.SIN_MOVIMIENTO:
		mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	var especie: String = lider.nombre
	await _mostrar_mensaje(texto_tu_pokemon, especie)
	if lider.cintas.has(CINTA):
		await _mostrar_mensaje(texto_ya_tiene, especie)
	elif suma_ev(lider) < EV_MAXIMOS:
		await _mostrar_mensaje(texto_esfuerzate, especie)
	else:
		await _mostrar_mensaje(texto_entrega, especie)
		# message + playfanfare + waitfanfare + waitmessage.
		_texto_recibida_listo = false
		continuar_dialogo(tr(texto_recibida), false, _marcar_texto_recibida_listo)
		await reproducir_fanfarria(fanfarria_objeto)
		if not _texto_recibida_listo:
			await _mensaje_terminado
		await _mostrar_mensaje(texto_puesta, especie)
		lider.cintas.append(CINTA)
	_finalizar()


func _marcar_texto_recibida_listo() -> void:
	_texto_recibida_listo = true
	_mensaje_terminado.emit()


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


## Espera el botón y deja el cuadro abierto para el siguiente mensaje.
func _mostrar_mensaje(clave: String, especie: String) -> void:
	continuar_dialogo(tr(clave).replace("{especie}", especie), true, _mensaje_terminado.emit)
	await _mensaje_terminado
