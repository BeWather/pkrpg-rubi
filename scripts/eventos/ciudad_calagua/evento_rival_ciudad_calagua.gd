## evento_rival_ciudad_calagua.gd
## Encuentro con el rival (AURA / BRUNO) delante del CENTRO COMERCIAL de CIUDAD CALAGUA
## (pokeruby LilycoveCity_EventScript_Rival / _May / _Brendan, (27,7) de Rubí).
##
## Al hablarle: suena su música, pregunta si quieres combatir (SÍ/NO; si ya dijiste que no,
## la pregunta cambia a «Venga, lucha conmigo»). Con NO se enfada (FLAG_DECLINED_RIVAL_
## BATTLE_LILYCOVE) y se queda. Con SÍ avisa, combate (equipo según tu inicial, ids 661–666)
## y, si ganas, cuenta que vuelve a VILLA RAÍZ y se despide con un texto que depende de las
## MEDALLAS 6 y 8 y de la LIGA superada; luego se va volando (LilycoveCity_EventScript_RivalFlyAway,
## FLAG_MET_RIVAL_LILYCOVE).
##
## Pendiente: FLAG_HIDE_MAY_UPSTAIRS / FLAG_HIDE_BRENDAN_UPSTAIRS / FLAG_HIDE_MAY_PICHU_DOLL
## (la habitación del rival en VILLA RAÍZ) no se tocan.
extends EventoRival
class_name EventoRivalCiudadCalagua

## Perder no cambia nada: el rival sigue esperando.
const BANDERA_RECHAZADO: String = "calagua_rival_rechazado"
## MEDALLA 6 y 8 (FLAG_BADGE06_GET, FLAG_BADGE08_GET): índices 0-based.
const INDICE_MEDALLA_6: int = 5
const INDICE_MEDALLA_8: int = 7
const BANDERA_JUEGO_COMPLETADO: String = "SYS_GAME_CLEAR"
## delay 50 de LilycoveCity_EventScript_RivalFlyAway.
const FOTOGRAMAS_ANTES_DE_IRSE: int = 50

## npc_rival del mapa.
@export var rival: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc := get_node_or_null(rival)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_rival_hablado)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _on_rival_hablado(npc: Node2D) -> void:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or completado() or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()  # faceplayer
	reproducir_musica_encuentro()
	var ya_rechazo := SistemaGuardado.get_flag(BANDERA_RECHAZADO)
	if not await preguntar_si_no(texto("REVANCHA" if ya_rechazo else "SALUDO")):
		SistemaGuardado.set_flag(BANDERA_RECHAZADO, true)
		await mensaje(texto("RECHAZO"))
		restaurar_musica_mapa()
		terminar(false, [npc])
		return
	await mensaje(texto("AVISO"))
	var resultado := await combatir_rival()
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		return
	await mensaje(texto("TRAS_COMBATE"))
	await mensaje(texto(_sufijo_despedida()))
	admin.cuadro_dialogo.cerrar()  # closemessage
	mirar(npc, Vector2.DOWN)
	await esperar_fotogramas(FOTOGRAMAS_ANTES_DE_IRSE)
	await salir_volando(npc)
	marcar_completado()  # FLAG_MET_RIVAL_LILYCOVE
	restaurar_musica_mapa()
	terminar(false, [npc])


## LilycoveCity_EventScript_CheckFinalBadge: con las MEDALLAS 6 y 8, LIGA o TORRE
## BATALLA (según FLAG_SYS_GAME_CLEAR); si no, «consigue todas las MEDALLAS».
func _sufijo_despedida() -> String:
	if SistemaGuardado.tiene_medalla(INDICE_MEDALLA_6) and SistemaGuardado.tiene_medalla(INDICE_MEDALLA_8):
		return "TORRE" if SistemaGuardado.get_flag(BANDERA_JUEGO_COMPLETADO) else "LIGA"
	return "INSIGNIAS"
