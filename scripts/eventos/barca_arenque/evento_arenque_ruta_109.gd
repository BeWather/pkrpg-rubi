## evento_arenque_ruta_109.gd
## SR. ARENQUE en el muelle de la RUTA 109 (pokeruby Route109_EventScript_14F680 y
## Route109_EventScript_14F4D3). Va en la RUTA 109, con ARENQUE (objeto 2) y su barca
## (objeto 1). Coordenadas de Godot = Rubí + (2,0).
##
## - Sin FLAG_DELIVERED_DEVON_GOODS: «¿No vas a entregar las PIEZAS DEVON? ¿Quieres
##   volver a AZULIZA?» (SÍ/NO). SÍ → rumbo a AZULIZA; NO → «yo te espero».
## - Con las PIEZAS entregadas: «¿adónde vamos?» con AZULIZA / SALIR (multichoice 14).
## - Rumbo a AZULIZA: ARENQUE baja a la barca (removeobject 2); el jugador va a la barca
##   según VAR_FACING (desde arriba: abajo ×2; desde la izquierda: derecha y abajo; desde
##   la derecha: izquierda y abajo) y se oculta; la barca recorre Route109_Movement_14F5BF
##   hasta (12,8) de PUEBLO AZULIZA; el jugador baja dos, va a la izquierda y mira a la
##   derecha; ARENQUE sale de la barca y mira a la izquierda.
extends EventoBarcaArenque
class_name EventoArenqueRuta109

const TEXTO_VOLVER: String = "RUTA109_ARENQUE_VOLVER"
const TEXTO_ADONDE: String = "RUTA109_ARENQUE_ADONDE"
const TEXTO_RUMBO_AZULIZA: String = "RUTA109_ARENQUE_RUMBO_AZULIZA"
const TEXTO_TE_ESPERO: String = "RUTA109_ARENQUE_TE_ESPERO"
const TEXTO_LLAMAME: String = "RUTA109_ARENQUE_LLAMAME"
const OPCION_AZULIZA: String = "ARENQUE_OPCION_AZULIZA"
const OPCION_SALIR: String = "ARENQUE_OPCION_SALIR"

## Route109_Movement_14F66D / 14F675 / 14F678 según la mirada del jugador al hablar.
const PASOS_EMBARQUE := {
	Vector2.DOWN: [Vector2.DOWN, Vector2.DOWN],
	Vector2.RIGHT: [Vector2.RIGHT, Vector2.DOWN],
	Vector2.LEFT: [Vector2.LEFT, Vector2.DOWN],
}
## El jugador viaja una casilla por encima de la barca: aparece en (12,7) de AZULIZA y
## Route109_Movement_14F670 lo baja dos y lo lleva a la izquierda.
const LLEGADA_JUGADOR := Vector2i(18, 7)

@export var arenque: NodePath
@export var barca_ruta_109: NodePath


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc_arenque := _npc(arenque)
	if npc_arenque != null and npc_arenque.has_signal("hablado"):
		npc_arenque.hablado.connect(_on_arenque_hablado)


## Route109_EventScript_14F680.
func _on_arenque_hablado(npc: Node2D) -> void:
	var mirada: Vector2 = npc.jugador.facing_direction if npc.jugador != null else Vector2.DOWN
	if not comenzar_con(npc):
		return
	var zarpar := false
	if not SistemaGuardado.get_flag(BANDERA_PIEZAS):
		zarpar = await preguntar_si_no(TEXTO_VOLVER)
		if not zarpar:
			await mensaje(TEXTO_TE_ESPERO)
	else:
		zarpar = await elegir_opcion(TEXTO_ADONDE, PackedStringArray([tr(OPCION_AZULIZA), tr(OPCION_SALIR)])) == 0
		if not zarpar:
			await mensaje(TEXTO_LLAMAME)
	if not zarpar:
		terminar(false, [npc])
		return
	await mensaje(TEXTO_RUMBO_AZULIZA)
	await viajar_a_azuliza_desde_109(npc, mirada)


## Route109_EventScript_14F4D3 (el guion ya empezó).
func viajar_a_azuliza_desde_109(npc_arenque: Node2D, mirada_jugador: Vector2) -> void:
	admin.cuadro_dialogo.cerrar()  # closemessage
	await caminar(npc_arenque, Vector2.DOWN)  # Route109_Movement_14F67B
	npc_arenque.visible = false  # removeobject 2
	SistemaGuardado.set_flag(BANDERA_ARENQUE_RUTA_109, false)
	await recorrer_jugador(PASOS_EMBARQUE.get(mirada_jugador, []))  # switch VAR_FACING
	admin.jugador.visible = false
	reproducir_musica(MUSICA_NAVEGAR)
	var npc_barca := _npc(barca_ruta_109)
	var origen := posicion_global(obtener_mapa(), BARCA_RUTA_109)
	if npc_barca != null:
		origen = pies_de(npc_barca)
		npc_barca.visible = false  # hideobjectat 1
	SistemaGuardado.set_flag(BANDERA_BARCA_RUTA_109, false)  # setflag FLAG_HIDE_MR_BRINEY_BOAT_ROUTE109
	await navegar(origen, TRAMOS_DESDE_PORTUAL)
	# showobjectat LOCALID_PLAYER, MAP_DEWFORD_TOWN + Route109_Movement_14F670.
	await llegar_a_azuliza(LLEGADA_JUGADOR, [Vector2.DOWN, Vector2.DOWN, Vector2.LEFT], TEXTO_LLEGADA)
