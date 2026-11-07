## Regalo de un NPC de PUEBLO AZULIZA (PAÑUELO DE SEDA o MT06).
extends EventoGuionizado
class_name EventoRegaloAzuliza

const MOTIVO_PAUSA: StringName = &"regalo_azuliza"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"

@export var npc: NodePath
@export var bandera_recibido: String
@export var objeto: String
@export var texto_regalo: String
@export var texto_sin_espacio: String
@export var texto_recibido: String

var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc_regalo := get_node_or_null(npc)
	if npc_regalo != null and npc_regalo.has_signal("hablado"):
		npc_regalo.hablado.connect(_on_npc_hablado)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _on_npc_hablado(npc_regalo: Node2D) -> void:
	var administrador_npc: Node = npc_regalo.nodo_administrador if npc_regalo.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc_regalo.jugador and npc_regalo.jugador.has_method("esperar_dialogo"):
			npc_regalo.jugador.esperar_dialogo(false)
		return
	npc_regalo.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc_regalo.mirar_jugador()
	if SistemaGuardado.get_flag(bandera_recibido):
		await mensaje(texto_recibido)
		terminar(false, [npc_regalo])
		return
	await mensaje(texto_regalo, false)
	if not await dar_objeto(npc_regalo, objeto):
		await mensaje(texto_sin_espacio if not texto_sin_espacio.is_empty() else TEXTO_MOCHILA_LLENA)
		terminar(false, [npc_regalo])
		return
	SistemaGuardado.set_flag(bandera_recibido, true)
	await mensaje(texto_recibido)
	terminar(false, [npc_regalo])
