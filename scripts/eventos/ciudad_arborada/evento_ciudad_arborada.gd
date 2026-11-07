## evento_ciudad_arborada.gd
## Guion del exterior de CIUDAD ARBORADA (pokeruby data/maps/FortreeCity/scripts.inc).
## Las celdas de Godot son las de Rubí.
##
## KECLEON (objeto 7, FortreeCity_EventScript_Kecleon): invisible y quieto en (25,8),
## corta el paso al GIMNASIO. Sin el DETECTOR DEVON solo avisa de que algo invisible
## corta el paso; con él pregunta si se usa y, al aceptar, el POKéMON se hace visible,
## suelta su grito, huye un paso a la derecha y desaparece (FLAG_KECLEON_FLED_FORTREE,
## que también es el inverso de FLAG_HIDE_KECLEON_FORTREE: la bandera lo oculta).
## Esa misma bandera cambia el texto de la MUJER que quiere entrar al GIMNASIO.
extends EventoGuionizado
class_name EventoCiudadArborada

const MOTIVO_PAUSA: StringName = &"ciudad_arborada"

## FLAG_KECLEON_FLED_FORTREE (≡ FLAG_HIDE_KECLEON_FORTREE).
const BANDERA_KECLEON_HUIDO: String = "arborada_kecleon_huido"
## ITEM_DEVON_SCOPE (DETECT.DEVON), en el bolsillo de objetos clave.
const OBJETO_DETECTOR: String = "DETECTDEVON"
const BOLSILLO_CLAVE: int = 4
## SPECIES_KECLEON.
const NUMERO_KECLEON: int = 352
## delay 40 entre que aparece y su grito.
const FOTOGRAMAS_ANTES_DEL_GRITO: int = 40

const T := "ARBORADA_KECLEON_"
const TEXTO_INVISIBLE: String = T + "INVISIBLE"
const TEXTO_PREGUNTA: String = T + "PREGUNTA"
const TEXTO_HUYE: String = T + "HUYE"

@export var kecleon: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc := get_node_or_null(kecleon)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_kecleon)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## FortreeCity_EventScript_Kecleon.
func _on_kecleon(npc: Node2D) -> void:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	if not SistemaGuardado.tiene_objeto(OBJETO_DETECTOR, 1, BOLSILLO_CLAVE):
		await mensaje(TEXTO_INVISIBLE)  # FortreeCity_Text_SomethingUnseeable
		terminar(false, [npc])
		return
	if not await preguntar_si_no(TEXTO_PREGUNTA):  # AskUseDevonScope
		terminar(false, [npc])
		return
	await _usar_detector(npc)


## FortreeCity_EventScript_UseDevonScope.
func _usar_detector(npc: Node2D) -> void:
	await mensaje(TEXTO_HUYE)
	# Movement_KecleonAppears: el sprite deja de estar oculto por el tipo INVISIBLE.
	npc.tipo_movimiento = NpcBase.TipoMovimientoNPC.SIN_MOVIMIENTO
	if npc.animated_sprite:
		npc.animated_sprite.visible = true
	var reproductor = grito(NUMERO_KECLEON)
	await esperar_fotogramas(FOTOGRAMAS_ANTES_DEL_GRITO)
	await esperar_grito(reproductor)
	await caminar(npc, Vector2.RIGHT)  # FortreeCity_Movement_KecleonFlee
	SistemaGuardado.set_flag(BANDERA_KECLEON_HUIDO, true)
	npc.aplicar_bandera_ocultar()  # removeobject VAR_LAST_TALKED
	terminar(false, [npc])
