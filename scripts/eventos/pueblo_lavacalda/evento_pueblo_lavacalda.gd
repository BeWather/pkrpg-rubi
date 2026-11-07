## evento_pueblo_lavacalda.gd
## Guion del exterior de PUEBLO LAVACALDA (pokeruby data/maps/LavaridgeTown/scripts.inc).
## Las celdas de Godot son las de Rubí.
##
## ABUELA del HUEVO (objeto 9, LavaridgeTown_EventScript_EggWoman): lock + faceplayer.
## Si ya lo entregó (FLAG_RECEIVED_LAVARIDGE_EGG) comenta la GUARDERÍA. Si no, ofrece el HUEVO
## de WYNAUT (SÍ/NO). NO → «como desees»; equipo lleno → «no te queda sitio» (sin bandera);
## SÍ → bandera, «recibió un HUEVO» con fanfarria y el huevo pasa al equipo.
##
## RIVAL (LavaridgeTown_OnFrame, VAR_LAVARIDGE_RIVAL_STATE 1 = `lavacalda_rival_esperando`): al volver
## al pueblo tras la MEDALLA sale de la tienda de HIERBAS (objeto 8), se acerca al jugador, suena su
## música, le da las GAFAS AISLANTES (FLAG_RECEIVED_GO_GOGGLES), explica el desierto y su plan de retar
## a su padre, y se va en BICI (objeto 7) (VAR_LAVARIDGE_RIVAL_STATE 2 = `lavacalda_rival_conocido`).
## Si la mochila está llena se queda y hablarle (_14E575) repite la entrega.
extends EventoRival
class_name EventoPuebloLavacalda

const MOTIVO_PAUSA: StringName = &"pueblo_lavacalda"

## FLAG_RECEIVED_LAVARIDGE_EGG.
const BANDERA_HUEVO: String = "lavacalda_huevo_recibido"
const ESPECIE_HUEVO: String = "WYNAUT"
const TAMANO_EQUIPO_MAXIMO: int = 6
## ITEM_GO_GOGGLES.
const OBJETO_GAFAS: String = "GAFASAISL"
## FLAG_RECEIVED_GO_GOGGLES.
const BANDERA_GAFAS: String = "lavacalda_gafas_recibidas"
## VAR_LAVARIDGE_RIVAL_STATE 1 (la activa el GIMNASIO al dar la MEDALLA).
const BANDERA_RIVAL_ESPERANDO: String = "lavacalda_rival_esperando"

## Warp del GIMNASIO: se llega a la puerta y se sale con un paso abajo.
const PUERTA_GIMNASIO: Vector2i = Vector2i(5, 15)
## Puerta de la tienda de HIERBAS (objeto 8) y salida en BICI (setobjectxyperm 7, 6, 16).
const CELDA_HERBOLARIO: Vector2i = Vector2i(12, 15)
const CELDA_BICI: Vector2i = Vector2i(6, 16)
## Common_Movement_Delay48.
const FOTOGRAMAS_TRAS_EXCLAMACION: int = 48
## delay 30 entre removeobject 8 / addobject 7 y la salida.
const FOTOGRAMAS_ANTES_DE_IRSE: int = 30
## LavaridgeTown_Movement_RivalApproachPlayer2.
const PASOS_ACERCARSE: Array[Vector2] = [Vector2.LEFT, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT]
## LavaridgeTown_Movement_RivalExit2.
const PASOS_SALIDA: Array[Vector2] = [Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT,
		Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP]

const T :="LAVACALDA_HUEVERA_"
const TEXTO_OFRECE: String = T + "OFRECE"
const TEXTO_ESPERO: String = T + "ESPERO"
const TEXTO_RECIBIDO: String = T + "RECIBIDO"
const TEXTO_YA: String = T + "YA"
const TEXTO_SIN_SITIO: String = T + "SIN_SITIO"
const TEXTO_NO: String = T + "NO"

@export var huevera: NodePath
@export var rival: NodePath
## npc_rival en BICI (objeto 7), oculto hasta que se va.
@export var rival_en_bici: NodePath
## Warp de la tienda de HIERBAS.
@export var puerta_herbolario: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc := get_node_or_null(huevera)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_huevera)
	var npc_rival := get_node_or_null(rival)
	if npc_rival != null and npc_rival.has_signal("hablado"):
		npc_rival.hablado.connect(_on_rival)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar_bici()


func _on_mapa_activado(_por_warp: bool) -> void:
	preparar_bici()
	if rival_pendiente():
		rival_da_gafas()  # LavaridgeTown_OnFrame


## VAR_LAVARIDGE_RIVAL_STATE == 1.
func rival_pendiente() -> bool:
	return SistemaGuardado.get_flag(BANDERA_RIVAL_ESPERANDO) and not completado()


## FLAG_HIDE_RIVAL_LAVARIDGE_2: la BICI solo aparece al irse.
func preparar_bici() -> void:
	var bici := get_node_or_null(rival_en_bici) as Node2D
	if bici != null and not _en_curso:
		colocar(bici, CELDA_BICI)
		bici.visible = false


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _empezar(npc: Node2D) -> bool:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()  # faceplayer
	return true


## LavaridgeTown_EventScript_EggWoman.
func _on_huevera(npc: Node2D) -> void:
	if not _empezar(npc):
		return
	if SistemaGuardado.get_flag(BANDERA_HUEVO):
		await mensaje(TEXTO_YA)  # ReceivedEgg
	elif not await preguntar_si_no(TEXTO_OFRECE):
		await mensaje(TEXTO_NO)  # DeclineEgg
	elif SistemaGuardado.get_equipo().size() >= TAMANO_EQUIPO_MAXIMO:
		await mensaje(TEXTO_SIN_SITIO)  # NoRoomForEgg
	else:
		await _dar_huevo()
	terminar(false, [npc])


func _dar_huevo() -> void:
	await mensaje(TEXTO_ESPERO)
	SistemaGuardado.set_flag(BANDERA_HUEVO, true)
	await mensaje_con_fanfarria(TEXTO_RECIBIDO)  # playfanfare MUS_OBTAIN_ITEM + message + waitfanfare
	admin.cuadro_dialogo.cerrar()
	var huevo := SistemaGuardado.get_guarderia().crear_huevo(ESPECIE_HUEVO)  # giveegg SPECIES_WYNAUT
	if huevo == null:
		push_warning("[PUEBLO_LAVACALDA] No se pudo crear el huevo de %s" % ESPECIE_HUEVO)
		return
	huevo.encuentro_lugar = Lugares.REGALO
	SistemaGuardado.get_equipo().append(huevo)


## LavaridgeTown_EventScript_RivalGiveGoGoggles.
func rival_da_gafas() -> void:
	var npc := get_node_or_null(rival) as Node2D
	if npc == null or not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	colocar(npc, CELDA_HERBOLARIO)
	npc.visible = false
	await esperar_fin_warp(admin)
	await completar_salida_puerta(PUERTA_GIMNASIO)
	var puerta := get_node_or_null(puerta_herbolario)
	Singleton.play_sound.emit("puerta_entrada")  # opendoor: SE_DOOR
	await abrir_puerta(puerta)
	npc.visible = true  # addobject 8
	await caminar(npc, Vector2.DOWN)  # LavaridgeTown_Movement_RivalExitHerbShop
	await cerrar_puerta(puerta)
	mirar(npc, Vector2.LEFT)
	girar_jugador(Vector2.RIGHT)
	await exclamacion(npc)
	await esperar_fotogramas(FOTOGRAMAS_TRAS_EXCLAMACION)
	reproducir_musica_encuentro()
	await recorrer(npc, PASOS_ACERCARSE)
	await _entregar_gafas(npc, true)


## LavaridgeTown_EventScript_14E575.
func _on_rival(npc: Node2D) -> void:
	if completado() or not _empezar(npc):
		return
	reproducir_musica_encuentro()
	await _entregar_gafas(npc, false)


## _MayGiveGoGoggles / _BrendanGiveGoGoggles + _RivalExit. Solo la escena de la tienda de HIERBAS
## tiene la salida en BICI; hablándole (VAR_0x8008 = 0) desaparece sin ella.
func _entregar_gafas(npc: Node2D, salir_en_bici: bool) -> void:
	await mensaje(texto("GAFAS"), false)
	if not await dar_objeto(npc, OBJETO_GAFAS):
		await mensaje("MOCHILA_LLENA_REGALO")
		restaurar_musica_mapa()
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(BANDERA_GAFAS, true)
	await mensaje(texto("EXPLICA"))
	admin.cuadro_dialogo.cerrar()  # closemessage
	npc.visible = false  # removeobject 8
	if salir_en_bici:
		await _salir_en_bici()
	marcar_completado()  # VAR_LAVARIDGE_RIVAL_STATE 2
	restaurar_musica_mapa()
	terminar(false, [npc])
	preparar_bici()


## addobject 7 + delay 30 + LavaridgeTown_EventScript_RivalExit2 + removeobject 7.
func _salir_en_bici() -> void:
	var bici := get_node_or_null(rival_en_bici) as Node2D
	if bici == null:
		return
	colocar(bici, CELDA_BICI)
	bici.visible = true
	await esperar_fotogramas(FOTOGRAMAS_ANTES_DE_IRSE)
	await recorrer(bici, PASOS_SALIDA, VelocidadPaso.RAPIDO)
	bici.visible = false
