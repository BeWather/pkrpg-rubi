## evento_guarida_calagua.gd
## Guion de la planta más baja de la GUARIDA (pokeruby data/maps/MagmaHideout_B2F/ y
## AquaHideout_B2F/scripts.inc, versión Rubí). Las celdas de la escena son las de Rubí.
##
## REACCIÓN (coord_events `*_EventScript_15D8BD`, `VAR_TEMP_1 == 0`): al pisar una de las
## celdas de disparo, TATIANO (objeto 1, el administrador de MAGMA) se sobresalta (SE_PIN +
## «!»), mira hacia arriba (Rubí; Zafiro se vuelve hacia el jugador) y `VAR_TEMP_1` pasa a 1.
## `VAR_TEMP_1` se borra al cargar el mapa: aquí, cada vez que el mapa pasa a ser el actual.
##
## TATIANO (`*_EventScript_15D8E1`, `trainerbattle_single TRAINER_HIDEOUT_B2F_GRUNT_1`): al
## hablarle (no ve al jugador, `TRAINER_TYPE_NONE`) muestra su desafío y combate. Vencido
## (`*_EventScript_15D8FD`): mira al submarino y espera 20 fotogramas, se vuelve hacia el
## jugador y revela que el JEFE ya terminó los preparativos; la sombra del submarino (objeto 3
## en Rubí) se aleja cuatro casillas y desaparece (`removeobject`, que activa
## FLAG_HIDE_SUBMARINE_SHADOW_HIDEOUT); tras otros 20 fotogramas TATIANO dice que el JEFE ya se
## ha ido a una cueva submarina, se activan FLAG_EVIL_TEAM_ESCAPED_IN_SUBMARINE y
## FLAG_HIDE_GRUNTS_LILYCOVE, y desde entonces repite ese último texto.
##
## Rubí y Zafiro difieren en el sentido: la guarida de MAGMA (Rubí) mira y empuja al submarino
## hacia la DERECHA y TATIANO se queda mirando arriba; la de AQUA usa la izquierda y se vuelve hacia
## el jugador. `direccion_submarino` y `reaccion` recogen esa diferencia.
extends EventoGuionizado
class_name EventoGuaridaCalagua

const MOTIVO_PAUSA: StringName = &"guarida_calagua"

const TEXTO_DESAFIO: String = "GUARIDA_B2F_TATIANO_INI"
const TEXTO_PREPARATIVOS: String = "GUARIDA_B2F_TATIANO_HUIDA"
const TEXTO_FUGA: String = "GUARIDA_B2F_TATIANO_POST"
## playse SE_PIN.
const SONIDO_EXCLAMACION: String = "SE_PIN"

## `delay 20` antes de mirar al jugador y tras desaparecer el submarino.
const FOTOGRAMAS_ESPERA: int = 20
## `walk_right ×4` / `walk_left ×4` del submarino (AquaHideout_B2F_Movement_15D95D / _15D958).
const PASOS_SUBMARINO: int = 4

## Cómo reacciona el jefe al pisar el jugador una celda de disparo.
enum Reaccion {
	MIRAR_ARRIBA,		# Common_Movement_WalkInPlaceFastestUp (Rubí)
	MIRAR_JUGADOR,		# Common_Movement_FacePlayer (Zafiro)
}

@export var jefe: NodePath = ^"../../NPCs/Tatiano"
@export var submarino: NodePath = ^"../../NPCs/Submarino"
## Hacia dónde mira TATIANO y se aleja el submarino.
@export var direccion_submarino: Vector2 = Vector2.RIGHT
@export var reaccion: Reaccion = Reaccion.MIRAR_ARRIBA

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## VAR_TEMP_1 == 1: ya reaccionó en esta visita.
var _reaccion_hecha: bool = false


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	var tatiano := _npc(jefe)
	if tatiano != null and tatiano.has_signal("hablado"):
		tatiano.hablado.connect(_on_jefe_hablado)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: _reaccion_hecha = false)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


## ¿Ha reaccionado ya el jefe en esta visita (VAR_TEMP_1)?
func reaccion_hecha() -> bool:
	return _reaccion_hecha


## ============================================================================
## COORD_EVENTS (VAR_TEMP_1 == 0)
## ============================================================================

func _on_disparador(_id: StringName) -> void:
	if _en_curso or _reaccion_hecha:
		return
	await reaccionar()


## `*_EventScript_15D8BD`: lockall, SE_PIN, «!», giro del jefe y VAR_TEMP_1 = 1.
func reaccionar() -> void:
	if not comenzar(_administrador()):
		return
	var tatiano := _npc(jefe)
	if tatiano != null:
		Singleton.play_sound.emit(SONIDO_EXCLAMACION)
		await exclamacion(tatiano)
		if reaccion == Reaccion.MIRAR_ARRIBA:
			mirar(tatiano, Vector2.UP)
		else:
			tatiano.mirar_jugador()
	_reaccion_hecha = true
	terminar(false, [])


## ============================================================================
## TATIANO
## ============================================================================

func _on_jefe_hablado(npc: Node2D) -> void:
	if _en_curso:
		return
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if not comenzar(administrador_npc):
		if npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()  # faceplayer
	# trainerbattle_single con el entrenador ya vencido: salta al msgbox que sigue.
	if SistemaGuardado.get_flag(npc.npc_id + "_combate"):
		await mensaje(TEXTO_FUGA)
		terminar(false, [npc])
		return
	npc.call(&"_reproducir_musica_presentacion")
	await mensaje(TEXTO_DESAFIO)
	var musica: String = npc.musica_batalla
	var resultado := await combatir(npc.entrenador_id, "" if musica == "Por defecto" else musica)
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		return
	SistemaGuardado.set_flag(npc.npc_id + "_combate", true)
	npc.combate_pendiente = false
	npc.id_texto = npc.texto_post_combate
	await escena_fuga(npc)
	terminar(false, [npc])


## `*_EventScript_15D8FD`: el JEFE ya se ha ido en el submarino.
func escena_fuga(npc: Node2D) -> void:
	var barco := _npc(submarino)
	mirar(npc, direccion_submarino)  # walk_in_place_fastest_right / left
	await esperar_fotogramas(FOTOGRAMAS_ESPERA)
	npc.mirar_jugador()  # Common_Movement_FacePlayer
	await mensaje(TEXTO_PREPARATIVOS)
	mirar(npc, direccion_submarino)
	if barco != null:
		var pasos: Array = []
		for i in PASOS_SUBMARINO:
			pasos.append(direccion_submarino)
		await recorrer(barco, pasos)
		barco.visible = false  # removeobject
	SistemaGuardado.set_flag(HistoriaGuaridaCalagua.BANDERA_SUBMARINO_OCULTO, true)
	await esperar_fotogramas(FOTOGRAMAS_ESPERA)
	npc.mirar_jugador()
	await mensaje(TEXTO_FUGA)
	SistemaGuardado.set_flag(HistoriaGuaridaCalagua.BANDERA_EQUIPO_ESCAPO, true)
	SistemaGuardado.set_flag(HistoriaGuaridaCalagua.BANDERA_SOLDADOS_CALAGUA_OCULTOS, true)
