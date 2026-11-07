## Guion de MÁXIMO (STEVEN) en su SALA de la CUEVA GRANITO.
## pokeruby data/maps/GraniteCave_StevensRoom/scripts.inc (EventScript_15CBFA):
## lock, faceplayer, msgbox, VAR_SPECIAL_4 = ITEM_LETTER + call EventScript_1A067F
## (fanfarria MUS_ME_WAZA, «¡{PN} entregó {objeto}!» y takeitem), FLAG_DELIVERED_STEVEN_LETTER,
## msgbox, giveitem_std ITEM_TM47_STEEL_WING (mochila llena: texto aparte, sin MT), msgbox,
## closemessage, applymovement (sale por la puerta según desde dónde le hablaste),
## playse SE_KAIDAN y removeobject (FLAG_HIDE_STEVEN_GRANITE_CAVE).
##
## Fiel a la ROM: no se comprueba que lleves la CARTA (takeitem sin ella no hace nada)
## y con la mochila llena MÁXIMO se va igualmente, sin la MT.
extends EventoGuionizado
class_name EventoMaximoCuevaGranito

const MOTIVO_PAUSA: StringName = &"maximo_cueva_granito"

## ITEM_LETTER.
const OBJETO_CARTA: String = "CARTAGUILLE"
## ITEM_TM47_STEEL_WING.
const OBJETO_MT: String = "MT47"
## FLAG_DELIVERED_STEVEN_LETTER (la leen la barca del SR. ARENQUE, DEVON S.A. y la casa del SR. ARENQUE).
const BANDERA_CARTA: String = "carta_maximo_entregada"
## FLAG_HIDE_STEVEN_GRANITE_CAVE (positiva: MÁXIMO ya se ha ido).
const BANDERA_IDO: String = "cueva_granito_maximo_ido"

## SE_KAIDAN (el mismo de las escaleras y cuevas de warp.gd).
const SONIDO_SALIDA: String = "puerta_salida"
## delay_8 final de los dos movimientos.
const FOTOGRAMAS_ESPERA_FINAL: int = 8

const TEXTO_CARTA: String = "CUEVA_GRANITO_MAXIMO_CARTA"
const TEXTO_ENTREGA: String = "CUEVA_GRANITO_MAXIMO_ENTREGA"
const TEXTO_GRACIAS: String = "CUEVA_GRANITO_MAXIMO_GRACIAS"
const TEXTO_DESPEDIDA: String = "CUEVA_GRANITO_MAXIMO_DESPEDIDA"
const TEXTO_MOCHILA_LLENA: String = "CUEVA_GRANITO_MAXIMO_MOCHILA_LLENA"

## GraniteCave_StevensRoom_Movement_15CC8C: cinco pasos al norte (hasta la puerta).
const SALIDA_RECTA: Array = [Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP]
## GraniteCave_StevensRoom_Movement_15CC93: rodea al jugador, que está entre él y la puerta.
const SALIDA_RODEANDO: Array = [
	Vector2.LEFT, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.RIGHT, Vector2.UP, Vector2.UP,
]

@export var maximo: NodePath

var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc_maximo := get_node_or_null(maximo)
	if npc_maximo != null and npc_maximo.has_signal("hablado"):
		npc_maximo.hablado.connect(_on_maximo_hablado)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _on_maximo_hablado(npc: Node2D) -> void:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	# FACING de Rubí: hacia dónde miraba el jugador al hablarle (abajo = está entre él y la puerta).
	var mirada_jugador: Vector2 = Vector2.UP
	if administrador_npc.get("jugador") != null:
		mirada_jugador = administrador_npc.jugador.facing_direction
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()  # faceplayer
	await mensaje(TEXTO_CARTA)
	await _entregar_carta()
	SistemaGuardado.set_flag(BANDERA_CARTA, true)
	await mensaje(TEXTO_GRACIAS, false)
	if not await dar_objeto(npc, OBJETO_MT):
		await mensaje(TEXTO_MOCHILA_LLENA)  # GraniteCave_StevensRoom_EventScript_15CC83
	await mensaje(TEXTO_DESPEDIDA)  # closemessage incluido
	if mirada_jugador.is_equal_approx(Vector2.DOWN):
		await recorrer(npc, SALIDA_RODEANDO)
	else:
		await recorrer(npc, SALIDA_RECTA)
	await esperar_fotogramas(FOTOGRAMAS_ESPERA_FINAL)
	Singleton.play_sound.emit(SONIDO_SALIDA)  # playse SE_KAIDAN
	npc.visible = false  # removeobject 1
	SistemaGuardado.set_flag(BANDERA_IDO, true)
	terminar(false, [npc])


## EventScript_1A067F: fanfarria de MT/MO, «¡{PN} entregó la CARTA!» y takeitem.
func _entregar_carta() -> void:
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(OBJETO_CARTA)
	await mensaje_con_fanfarria(TEXTO_ENTREGA, Fanfarria.TEMA_MT_MO,
			{"{objeto}": str(datos.get("nombre", OBJETO_CARTA))})
	SistemaGuardado.quitar_objeto_jugador(OBJETO_CARTA, 1, int(datos.get("bolsillo_id", 0)))
