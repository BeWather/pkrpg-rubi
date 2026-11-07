## evento_casa_maximo.gd
## CASA de MÁXIMO en CIUDAD ALGARIA (pokeruby MossdeepCity_StevensHouse; STEVEN = MÁXIMO). Godot = Rubí.
##
## OnFrame con VAR_STEVENS_HOUSE_STATE = 0 (contador `algaria_casa_maximo_estado`) al entrar en la casa: MÁXIMO (objeto 1,
## (9,6), FACE_RIGHT) mira a la izquierda, se asombra («!» con SE_PIN), espera 48 fotogramas, camina 6 casillas a la
## izquierda hasta quedar frente a la puerta, te da la MO08 BUCEO (FLAG_RECEIVED_HM08 ≡ `algaria_mo08_recibida` y
## FLAG_OMIT_DIVE_FROM_STEVEN_LETTER ≡ `algaria_omitir_buceo_carta`), explica el BUCEO, espera 20 fotogramas, sube
## una casilla y va 3 a la derecha mirando arriba, y el estado pasa a 1. Con el estado en 1 MÁXIMO se coloca ya en (6,5)
## mirando arriba al activarse el mapa (OnTransition: setobjectxyperm 1, 6, 5 + setobjectmovementtype 1, 7). Hablarle
## cuenta lo de la gruta submarina. FLAG_HIDE_STEVEN_STEVENS_HOUSE ≡ `algaria_maximo_oculto` (la activa la SIMA
## DEL FONDO MARINO, aún sin migrar).
##
## Tras la LIGA (SYS_GAME_CLEAR, aquí en vez del SALÓN DE LA FAMA, que aún no existe) aparecen sobre la mesa:
## - la CARTA (objeto 4, invisible, (6,4)): su texto menciona la MO BUCEO solo si no llevas FLAG_OMIT_DIVE...;
## - la POKé BALL con el BELDUM (objeto 2, (4,3)): SÍ/NO; sin sitio en el equipo no se marca; con SÍ, fanfarria, BELDUM
##   nivel 5 (regalo) y la pregunta del mote; FLAG_RECEIVED_BELDUM ≡ `algaria_beldum_recibido`;
## - la bola de la MO08 (objeto 3, (5,3)) si no la tienes: es un ItemOverworld normal (`bandera_al_recoger`).
## No se migra el setmetatile 753 en (6,4) que OnLoad pone antes de SYS_GAME_CLEAR (el dibujo de la mesa es del mapa).
extends EventoInteriorMalvalona
class_name EventoCasaMaximo

const MOTIVO_PAUSA: StringName = &"casa_maximo"

## VAR_STEVENS_HOUSE_STATE.
const CONTADOR_ESTADO: String = "algaria_casa_maximo_estado"
## FLAG_RECEIVED_HM08, FLAG_OMIT_DIVE_FROM_STEVEN_LETTER, FLAG_RECEIVED_BELDUM, FLAG_HIDE_STEVEN_STEVENS_HOUSE.
const BANDERA_MO08: String = "algaria_mo08_recibida"
const BANDERA_OMITIR_BUCEO: String = "algaria_omitir_buceo_carta"
const BANDERA_BELDUM: String = "algaria_beldum_recibido"
const BANDERA_MAXIMO_OCULTO: String = "algaria_maximo_oculto"
const OBJETO_MO08: String = "MO08"
const ESPECIE_BELDUM: String = "BELDUM"
const NIVEL_BELDUM: int = 5
## SistemaGuardado.agregar_pokemon_al_equipo: origen REGALO.
const ORIGEN_REGALO: int = 3
const MAX_EQUIPO: int = 6
const SONIDO_EXCLAMACION: String = "SE_PIN"
## Common_Movement_Delay48 y delay 20.
const FOTOGRAMAS_DELAY_48: int = 48
const FOTOGRAMAS_DELAY_20: int = 20
## MossdeepCity_StevensHouse_Movement_15AA6E: 6 pasos a la izquierda y mira abajo. _15AA76: arriba, 3 a la derecha, mira arriba.
const PASOS_HASTA_LA_PUERTA: int = 6
const PASOS_A_LA_MESA: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT]
## Dónde se queda MÁXIMO con el estado en 1.
const CELDA_DE_MAXIMO: Vector2i = Vector2i(6, 5)

const T := "ALGARIA_CASA1_"
const TEXTO_MO08: String = T + "MO08"
const TEXTO_BUCEO: String = T + "BUCEO"
const TEXTO_MAXIMO: String = T + "MAXIMO"
const TEXTO_CARTA: String = T + "CARTA"
const TEXTO_CARTA_MO: String = T + "CARTA_MO"
const TEXTO_BELDUM_PREGUNTA: String = T + "BELDUM_PREGUNTA"
const TEXTO_BELDUM_OBTENIDO: String = T + "BELDUM_OBTENIDO"
const TEXTO_BELDUM_SIN_ESPACIO: String = T + "BELDUM_SIN_ESPACIO"
const TEXTO_BELDUM_NO: String = T + "BELDUM_NO"
## Los mismos textos del mote que el FÓSIL de la CORPORACIÓN DEVON.
const TEXTO_MOTE: String = "FERRICA_DEVON_2F_FOSIL_MOTE"

## Pantalla de nombre (Common_EventScript_NameReceivedPartyMon), como en EventoDevonFerrica.
const SCN_ENTRADA_NOMBRE: PackedScene = preload("res://escenas/entrada_nombre/entrada_nombre.tscn")
const TITULO_MOTE: String = "¿Mote de %s?"
const MAX_CARACTERES_MOTE: int = 10
const ENTRADA_NOMBRE_POKEMON: int = 2

@export var maximo: NodePath
@export var carta: NodePath
@export var pelota_beldum: NodePath

## Sustituye a la pantalla de nombre (tests): recibe el BasePokemon y devuelve el mote.
var pedir_mote: Callable = Callable()

signal _nombre_introducido(nombre: String)


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(maximo, _on_maximo)
	escuchar(carta, _on_carta)
	escuchar(pelota_beldum, _on_beldum)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	_colocar_tras_la_escena()


func _on_mapa_activado(_por_warp: bool) -> void:
	if SistemaGuardado.get_flag(BANDERA_MAXIMO_OCULTO):
		return
	if SistemaGuardado.get_contador(CONTADOR_ESTADO) == 0:
		escena_del_buceo()  # map_script_2 VAR_STEVENS_HOUSE_STATE, 0
	else:
		_colocar_tras_la_escena()


## OnTransition con el estado en 1: MÁXIMO en (6,5) mirando arriba (también su celda de origen).
func _colocar_tras_la_escena() -> void:
	var npc := nodo(maximo)
	if npc == null or SistemaGuardado.get_contador(CONTADOR_ESTADO) < 1:
		return
	npc.tipo_movimiento = NpcBase.TipoMovimientoNPC.MIRAR_ARRIBA
	colocar(npc, CELDA_DE_MAXIMO)


## ============================================================================
## OnFrame: la MO BUCEO
## ============================================================================

## MossdeepCity_StevensHouse_EventScript_15AA0B.
func escena_del_buceo() -> void:
	var npc := nodo(maximo)
	if npc == null or not comenzar(_administrador()):
		return
	await esperar_fin_warp(admin)
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	mirar(npc, L)  # Common_Movement_WalkInPlaceFastestLeft
	Singleton.play_sound.emit(SONIDO_EXCLAMACION)
	await exclamacion(npc)
	await esperar_fotogramas(FOTOGRAMAS_DELAY_48)
	for i in PASOS_HASTA_LA_PUERTA:
		await caminar(npc, L)
	mirar(npc, D)
	await mensaje(TEXTO_MO08, false)
	if not await dar_objeto(npc, OBJETO_MO08):
		await mensaje_mochila_llena()
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(BANDERA_MO08, true)
	SistemaGuardado.set_flag(BANDERA_OMITIR_BUCEO, true)
	await mensaje(TEXTO_BUCEO)
	admin.cuadro_dialogo.cerrar()  # closemessage
	await esperar_fotogramas(FOTOGRAMAS_DELAY_20)
	await recorrer(npc, PASOS_A_LA_MESA)
	SistemaGuardado.set_contador(CONTADOR_ESTADO, 1)
	_colocar_tras_la_escena()
	terminar(false, [npc])


## MossdeepCity_StevensHouse_EventScript_15AAF9 (MSGBOX_NPC).
func _on_maximo(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	await mensaje(TEXTO_MAXIMO)
	terminar(false, [npc])


## ============================================================================
## La CARTA y el BELDUM (tras la LIGA)
## ============================================================================

## MossdeepCity_StevensHouse_EventScript_15AB02 (lockall).
func _on_carta(npc: Node2D) -> void:
	if not empezar_con(npc, false):
		return
	await mensaje(TEXTO_CARTA if SistemaGuardado.get_flag(BANDERA_OMITIR_BUCEO) else TEXTO_CARTA_MO)
	terminar(false, [npc])


## MossdeepCity_StevensHouse_EventScript_15AA7C (lockall).
func _on_beldum(pelota: Node2D) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	if not await preguntar_si_no(TEXTO_BELDUM_PREGUNTA):
		await mensaje(TEXTO_BELDUM_NO)  # EventScript_15AAE6
		terminar()
		return
	if SistemaGuardado.get_equipo().size() >= MAX_EQUIPO:
		await mensaje(TEXTO_BELDUM_SIN_ESPACIO)  # EventScript_15AADC
		terminar()
		return
	pelota.visible = false  # removeobject 2
	await mensaje_con_fanfarria(TEXTO_BELDUM_OBTENIDO)
	var seccion: String = ""
	if admin.has_method("obtener_seccion_lugar_actual"):
		seccion = str(admin.obtener_seccion_lugar_actual())
	var recibido: bool = SistemaGuardado.agregar_pokemon_al_equipo(ESPECIE_BELDUM, NIVEL_BELDUM, "", ORIGEN_REGALO, seccion)
	SistemaGuardado.set_flag(BANDERA_BELDUM, true)
	var pokemon: BasePokemon = SistemaGuardado.get_equipo().back() if recibido else null
	var nombre: String = pokemon.nombre if pokemon != null else ESPECIE_BELDUM
	if await preguntar_si_no(TEXTO_MOTE, {"{mon}": nombre}) and pokemon != null:
		await _poner_mote(pokemon)
	terminar()


## Common_EventScript_NameReceivedPartyMon.
func _poner_mote(pokemon: BasePokemon) -> void:
	admin.cuadro_dialogo.cerrar()
	var mote: String = ""
	if pedir_mote.is_valid():
		mote = str(await pedir_mote.call(pokemon))
	else:
		mote = await _pantalla_de_nombre(pokemon)
	if not mote.is_empty():
		pokemon.mote = mote


func _pantalla_de_nombre(pokemon: BasePokemon) -> String:
	var capa: Node = admin.get_node_or_null("Menu")
	if capa == null:
		return ""
	await oscurecer_pantalla()
	var entrada := SCN_ENTRADA_NOMBRE.instantiate() as Control
	entrada.z_index = 2
	var respuesta := {"lista": false, "nombre": ""}
	entrada.connect("nombre_confirmado", func(nombre: String) -> void:
		respuesta["lista"] = true
		respuesta["nombre"] = nombre
		_nombre_introducido.emit(nombre), CONNECT_ONE_SHOT)
	entrada.connect("cancelado", func() -> void:
		respuesta["lista"] = true
		_nombre_introducido.emit(""), CONNECT_ONE_SHOT)
	capa.add_child(entrada)
	entrada.call("configurar", TITULO_MOTE % pokemon.get_nombre_mostrar(), MAX_CARACTERES_MOTE,
		false, ENTRADA_NOMBRE_POKEMON, maxi(pokemon.numero_nacional, 1))
	await aclarar_pantalla()
	if not bool(respuesta["lista"]):
		await _nombre_introducido
	await oscurecer_pantalla()
	entrada.queue_free()
	await aclarar_pantalla()
	return str(respuesta["nombre"]).strip_edges()
