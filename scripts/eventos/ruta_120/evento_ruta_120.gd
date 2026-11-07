## evento_ruta_120.gd
## KECLEON invisibles y MÁXIMO en la RUTA 120 (pokeruby data/maps/Route120/scripts.inc y
## data/scripts/static_pokemon.inc). STEVEN = MÁXIMO. Godot = Rubí + (0,0).
##
## MÁXIMO (objeto 31, (13,15), Route120_EventScript_151853): espera en el puente junto al KECLEON
## invisible (objeto 30, (12,16)). Si el jugador no está listo se queda esperando
## (FLAG_NOT_READY_FOR_BATTLE_ROUTE120 acorta la pregunta). Si lo está, usa el DETECTOR DEVON, el
## KECLEON aparece y ataca (Nv. 30). Tras el combate, se gane, se huya o se capture, MÁXIMO da el
## DETECTOR y se marcha volando. Si el jugador pierde no cambia nada y el guion se repite, como el
## dowildbattle de Rubí, que acaba en el centro POKéMON sin volver al guion.
##
## KECLEON sueltos (objetos 37 a 41): EventoKecleonInvisible.
##
## SOMBRA (objeto 36, KECLEON_2 en (12,16), elevación 3): el mismo KECLEON bajo el puente, del que solo
## se ve el reflejo en el agua (NpcSombraPuente). Sin el DETECTOR mira a la derecha
## (Route120_EventScript_1516DA), y con él ya no está.
##
## NO migrado: los setmetatile de Route120_EventScript_1516B5 quitan el reflejo de MÁXIMO pintado en
## los metatiles 0x2F5 y 0x2F4 de Rubí. En Godot esas celdas ya son puente y agua normales.
extends EventoKecleonInvisible
class_name EventoRuta120

const MOTIVO_PAUSA: StringName = &"ruta_120"

## FLAG_RECEIVED_DEVON_SCOPE.
const BANDERA_DETECTOR: String = "ruta_120_detector_recibido"
## FLAG_NOT_READY_FOR_BATTLE_ROUTE120.
const BANDERA_NO_LISTO: String = "ruta_120_no_listo"
## FLAG_HIDE_STEVEN_ROUTE120.
const BANDERA_MAXIMO: String = "ruta_120_maximo_oculto"
## FLAG_HIDE_KECLEON_ROUTE120_1 (objeto 30) y _2 (objeto 36).
const BANDERA_KECLEON_PUENTE: String = "ruta_120_kecleon_1_oculto"
const BANDERA_SOMBRA: String = "ruta_120_kecleon_2_oculto"

## delay 20 antes de usar el DETECTOR y delay 50 antes de irse.
const FOTOGRAMAS_DELAY_20: int = 20
const FOTOGRAMAS_DELAY_50: int = 50

const T := "RUTA120_"
const TEXTO_MAXIMO_INI: String = T + "MAXIMO_INI"
const TEXTO_MAXIMO_NO_LISTO: String = T + "MAXIMO_NO_LISTO"
const TEXTO_MAXIMO_LISTO: String = T + "MAXIMO_LISTO"
const TEXTO_MAXIMO_COMBATE: String = T + "MAXIMO_COMBATE"
const TEXTO_MAXIMO_DETECTOR: String = T + "MAXIMO_DETECTOR"
const TEXTO_MAXIMO_REGALO: String = T + "MAXIMO_REGALO"
const TEXTO_MAXIMO_ADIOS: String = T + "MAXIMO_ADIOS"

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

@export var maximo: NodePath
@export var kecleon_puente: NodePath
@export var sombra: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	var npc_maximo := get_node_or_null(maximo)
	if npc_maximo != null and npc_maximo.has_signal("hablado"):
		npc_maximo.hablado.connect(_on_maximo)
	var npc_puente := get_node_or_null(kecleon_puente)
	if npc_puente != null and npc_puente.has_signal("hablado"):
		npc_puente.hablado.connect(_on_kecleon_puente)


## Route120_EventScript_151998: el objeto 30 solo avisa, incluso si el jugador ya tuviera el DETECTOR.
func _on_kecleon_puente(npc: Node2D) -> void:
	if not _empezar_con(npc):
		return
	await mensaje(TEXTO_INVISIBLE)  # Text_SomethingUnseeable
	terminar(false, [npc])


## Route120_EventScript_151853 y _151884.
func _on_maximo(npc: Node2D) -> void:
	if not _empezar_con(npc):
		return
	var clave := TEXTO_MAXIMO_LISTO if SistemaGuardado.get_flag(BANDERA_NO_LISTO) else TEXTO_MAXIMO_INI
	if not await preguntar_si_no(clave):
		# Route120_EventScript_151877.
		await mensaje(TEXTO_MAXIMO_NO_LISTO)
		SistemaGuardado.set_flag(BANDERA_NO_LISTO, true)
		terminar(false, [npc])
		return
	await _combate_maximo(npc)


## Route120_EventScript_15189D.
func _combate_maximo(npc: Node2D) -> void:
	await mensaje(TEXTO_MAXIMO_COMBATE)
	admin.cuadro_dialogo.cerrar()
	await _colocar_jugador_junto_al_kecleon()
	mirar(npc, L)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_20)
	await mensaje(TEXTO_MAXIMO_DETECTOR)
	admin.cuadro_dialogo.cerrar()
	var npc_kecleon := get_node_or_null(kecleon_puente) as Node2D
	if npc_kecleon == null:
		terminar(false, [npc])
		return
	npc_kecleon.tipo_movimiento = NpcBase.TipoMovimientoNPC.SIN_MOVIMIENTO
	mirar(npc_kecleon, R)
	await _aparecer(npc_kecleon)
	var resultado := await _combatir_kecleon()
	if resultado != Combate.SIGUE:
		_volver_invisible(npc_kecleon)
		terminar(resultado == Combate.DERROTA_TRANSFERIDA, [npc])
		return
	# Route120_EventScript_151628 con VAR_0x8004 == 0: removeobject 30 y 36 al volver al mapa.
	SistemaGuardado.set_flag(BANDERA_KECLEON_PUENTE, true)
	SistemaGuardado.set_flag(BANDERA_SOMBRA, true)
	npc_kecleon.aplicar_bandera_ocultar()
	var npc_sombra := get_node_or_null(sombra)
	if npc_sombra != null:
		npc_sombra.aplicar_bandera_ocultar()
	await _dar_detector(npc)


## VAR_FACING 2 (norte, desde (13,16)): mira al KECLEON. VAR_FACING 3 (oeste, desde (14,15)): baja y va
## a (13,16). Desde el oeste del puente (12,15) mira al este y se queda como está, igual que en Rubí.
func _colocar_jugador_junto_al_kecleon() -> void:
	var mirada: Vector2 = admin.jugador.facing_direction
	if mirada == U:
		girar_jugador(L)  # Route120_EventScript_15197F
	elif mirada == L:
		await recorrer_jugador([D, L])  # Route120_Movement_151995


## Route120_EventScript_151908.
func _dar_detector(npc: Node2D) -> void:
	mirar(npc, D)
	girar_jugador(U)
	await mensaje(TEXTO_MAXIMO_REGALO)
	await dar_objeto(npc, OBJETO_DETECTOR)
	SistemaGuardado.set_flag(BANDERA_DETECTOR, true)
	await mensaje(TEXTO_MAXIMO_ADIOS)
	admin.cuadro_dialogo.cerrar()
	mirar(npc, D)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_50)
	SistemaGuardado.set_flag(BANDERA_MAXIMO, true)
	await salir_volando(npc)
	terminar(false, [npc])
