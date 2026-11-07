## evento_laboratorio_abedul.gd
## LABORATORIO POKéMON del PROF. ABEDUL (pokeruby
## data/maps/LittlerootTown_ProfessorBirchsLab/scripts.inc). El estado es
## VAR_BIRCH_LAB_STATE (HistoriaVillaRaiz.estado_laboratorio()).
##
## - Estado 2 (tras el rescate de la Ruta 101): ABEDUL te regala el POKéMON, ofrece
##   ponerle mote y te pide ir a ver al rival a la RUTA 103 (→ 3).
## - Estado 4 (tras vencer al rival en la RUTA 103): te da la POKéDEX (PokedexPartida) y
##   el rival, 5 POKé BALLS (→ 5, empieza la aventura y MAMÁ espera con las
##   DEPORTIVAS).
## - El ayudante, ABEDUL y el rival hablan según el estado.
##
## Sin equivalente: la valoración de la POKéDEX (ProfBirch_EventScript_AskRatePokedex)
## depende de la POKéDEX real; ABEDUL dice el texto del estado 5 en su lugar.
extends EventoGuionizado
class_name EventoLaboratorioAbedul

const MOTIVO_PAUSA: StringName = &"laboratorio_abedul"
const TipoMovimiento := NpcBase.TipoMovimientoNPC

const BANDERA_AYUDANTE: String = "laboratorio_ayudante_visto"  # FLAG_BIRCH_AIDE_MET

const TEXTO_TE_DOY_POKEMON: String = "LAB_ABEDUL_TE_DOY_POKEMON"
const TEXTO_MOTE: String = "LAB_ABEDUL_MOTE"
const TEXTO_NO_SEAS_ASI: String = "LAB_ABEDUL_NO_SEAS_ASI"
const TEXTO_POKEDEX_RECIBIDA: String = "LAB_POKEDEX_RECIBIDA"
const TEXTO_TE_ESPERAN: String = "LAB_ABEDUL_TE_ESPERAN"
const TEXTO_TRABAJO_CAMPO: String = "LAB_AYUDANTE_TRABAJO_CAMPO"
const TEXTO_NO_ES_DE_MESA: String = "LAB_AYUDANTE_NO_ES_DE_MESA"
## Con variante _AURA / _BRUNO.
const TEXTO_VER_RIVAL: String = "LAB_ABEDUL_VER_RIVAL"
const TEXTO_ESTUPENDO: String = "LAB_ABEDUL_ESTUPENDO"
const TEXTO_RUTA_103: String = "LAB_ABEDUL_RUTA_103"
const TEXTO_TOMA_POKEDEX: String = "LAB_ABEDUL_TOMA_POKEDEX"
const TEXTO_EXPLICA_POKEDEX: String = "LAB_ABEDUL_EXPLICA_POKEDEX"
const TEXTO_RIVAL_TOMA_BALLS: String = "LAB_RIVAL_TOMA_BALLS"
const TEXTO_RIVAL_MOCHILA_LLENA: String = "LAB_RIVAL_MOCHILA_LLENA"
const TEXTO_RIVAL_ATRAPAR: String = "LAB_RIVAL_ATRAPAR"
const TEXTO_RIVAL_ADONDE_IR: String = "LAB_RIVAL_ADONDE_IR"
const TEXTO_AYUDA_RIVAL: String = "LAB_AYUDANTE_AYUDA_RIVAL"

const TEXTO_MAQUINA_NACIONAL: String = "LAB_MAQUINA_DEX_NACIONAL"
const TEXTO_DEX_NACIONAL: String = "LAB_POKEDEX_NACIONAL"
const TEXTO_DEX_NACIONAL_EXPLICA: String = "LAB_POKEDEX_NACIONAL_EXPLICA"
## Medallas exigidas por las máquinas para activar la POKéDEX Nacional.
const MEDALLAS_DEX_NACIONAL: int = 8

const OBJETO_BALLS: String = "POKEBALL"
const CANTIDAD_BALLS: int = 5

## Celdas (iguales en Rubí y en Godot).
const ABEDUL_CELDA := Vector2i(6, 4)
const RIVAL_CELDA := Vector2i(7, 4)
## PlayerEnterLabForPokedex: sube hasta delante de ABEDUL.
const ANTE_ABEDUL := Vector2i(6, 5)

## Pantalla de nombre (Common_EventScript_NameReceivedPartyMon).
const SCN_ENTRADA_NOMBRE: PackedScene = preload("res://escenas/entrada_nombre/entrada_nombre.tscn")
const TITULO_MOTE: String = "¿Mote de %s?"
const MAX_CARACTERES_MOTE: int = 10
const ENTRADA_NOMBRE_POKEMON: int = 2

@export var abedul: NodePath
@export var rival: NodePath
@export var ayudante: NodePath
## Carteles (CartelEvento) de las máquinas que actualizan la POKéDEX a la Nacional.
@export var maquinas: Array[NodePath] = []

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## Sustituye a la pantalla de nombre (tests): recibe el BasePokemon y devuelve el mote.
var pedir_mote: Callable = Callable()

signal _nombre_introducido(nombre: String)


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_conectar(abedul, _on_abedul_hablado)
	_conectar(rival, _on_rival_hablado)
	_conectar(ayudante, _on_ayudante_hablado)
	for ruta in maquinas:
		var cartel := get_node_or_null(ruta)
		if cartel is CartelEvento:
			cartel.accionado.connect(_on_maquina)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar()


func _conectar(ruta: NodePath, metodo: Callable) -> void:
	var nodo := get_node_or_null(ruta)
	if nodo != null and nodo.has_signal("hablado"):
		nodo.hablado.connect(metodo)


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## FLAG_HIDE_BIRCH_IN_LAB y FLAG_HIDE_RIVAL_BIRCH_LAB.
func preparar() -> void:
	if _en_curso:
		return
	var npc_abedul := _npc(abedul)
	if npc_abedul != null:
		colocar(npc_abedul, ABEDUL_CELDA)
		npc_abedul.visible = HistoriaVillaRaiz.abedul_en_laboratorio()
	var npc_rival := _npc(rival)
	if npc_rival != null:
		colocar(npc_rival, RIVAL_CELDA)
		npc_rival.visible = HistoriaVillaRaiz.rival_en_laboratorio()


func _on_mapa_activado(_por_warp: bool) -> void:
	preparar()
	match HistoriaVillaRaiz.estado_laboratorio():
		2:
			await esperar_fin_warp(_administrador())
			await dar_el_inicial()
		4:
			await esperar_fin_warp(_administrador())
			await dar_la_pokedex()


## LittlerootTown_ProfessorBirchsLab_EventScript_GiveStarterEvent.
func dar_el_inicial() -> void:
	if HistoriaVillaRaiz.estado_laboratorio() != 2 or not comenzar(_administrador()):
		return
	girar_jugador(Vector2.UP)  # LittlerootTown_ProfessorBirchsLab_EventScript_152CA7
	# El elegido en el bolso de la Ruta 101, no el primero del equipo (puede haber
	# capturas anteriores delante).
	var inicial: BasePokemon = SistemaGuardado.get_pokemon_inicial()
	var especie: String = inicial.nombre if inicial != null else ""
	# message + waitmessage + playfanfare MUS_OBTAIN_ITEM + waitfanfare.
	await _mensaje_sin_esperar(TEXTO_TE_DOY_POKEMON, {"{mon}": especie})
	await fanfarria(FANFARRIA_OBJETO)
	if await preguntar_si_no(TEXTO_MOTE, {"{mon}": especie}) and inicial != null:
		await _poner_mote(inicial)
	var acepta := await preguntar_si_no(HistoriaVillaRaiz.texto_rival(TEXTO_VER_RIVAL))
	while not acepta:
		acepta = await preguntar_si_no(TEXTO_NO_SEAS_ASI)
	await mensaje(HistoriaVillaRaiz.texto_rival(TEXTO_ESTUPENDO))
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_VER_RIVAL, true)  # VAR_BIRCH_LAB_STATE = 3
	terminar()


func _mensaje_sin_esperar(clave: String, reemplazos: Dictionary) -> void:
	var pendiente := [true]
	var al_terminar := func() -> void: pendiente[0] = false
	admin.cuadro_dialogo.mostrar(_texto(clave, reemplazos), false, false, al_terminar)
	while pendiente[0]:
		await get_tree().process_frame


## Common_EventScript_NameReceivedPartyMon: pantalla de nombre del primer POKéMON.
func _poner_mote(pokemon: BasePokemon) -> void:
	admin.cuadro_dialogo.cerrar()
	var mote := ""
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
	entrada.z_index = 2  # por encima del cuadro de diálogo y por debajo del Telon
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


## LittlerootTown_ProfessorBirchsLab_EventScript_GivePokedexEvent.
func dar_la_pokedex() -> void:
	if HistoriaVillaRaiz.estado_laboratorio() != 4 or not comenzar(_administrador()):
		return
	var npc_rival := _npc(rival)
	var celda: Vector2i = admin.jugador.pos_celda_act
	var pasos: Array = []
	for i in maxi(celda.y - ANTE_ABEDUL.y, 0):
		pasos.append(Vector2.UP)
	await recorrer_jugador(pasos)
	await mensaje(HistoriaVillaRaiz.texto_rival(TEXTO_TOMA_POKEDEX), false)
	# LittlerootTown_ProfessorBirchsLab_EventScript_ReceivePokedex.
	await mensaje_con_fanfarria(TEXTO_POKEDEX_RECIBIDA)
	PokedexPartida.obtener()  # setflag FLAG_SYS_POKEDEX_GET
	# La opción POKéDEX aparece en el menú de pausa desde este momento.
	if admin.has_method("actualizar_opciones_menu"):
		admin.actualizar_opciones_menu()
	await mensaje(HistoriaVillaRaiz.texto_rival(TEXTO_EXPLICA_POKEDEX))
	admin.cuadro_dialogo.cerrar()
	if npc_rival != null:
		await caminar(npc_rival, Vector2.DOWN)  # RivalApproachPlayer
		mirar(npc_rival, Vector2.LEFT)
	girar_jugador(Vector2.RIGHT)
	await mensaje(HistoriaVillaRaiz.texto_rival(TEXTO_RIVAL_TOMA_BALLS), false)
	var entregadas := false
	if npc_rival != null:
		entregadas = await dar_objeto(npc_rival, OBJETO_BALLS, CANTIDAD_BALLS)
	else:
		entregadas = bool(SistemaGuardado.dar_objeto_jugador(OBJETO_BALLS, CANTIDAD_BALLS).get("exito", false))
	if not entregadas:
		await mensaje(HistoriaVillaRaiz.texto_rival(TEXTO_RIVAL_MOCHILA_LLENA), false)
	await mensaje(HistoriaVillaRaiz.texto_rival(TEXTO_RIVAL_ATRAPAR))
	# VAR_BIRCH_LAB_STATE 5, FLAG_ADVENTURE_STARTED, VAR_LITTLEROOT_STATE 3 (POKéDEX).
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_AVENTURA, true)
	terminar(false, [npc_rival] if npc_rival != null else [])


## LittlerootTown_ProfessorBirchsLab_EventScript_152D9A (sin valoración de la POKéDEX).
func _on_abedul_hablado(npc: Node2D) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	npc.mirar_jugador()
	if HistoriaVillaRaiz.estado_laboratorio() >= 5:
		await mensaje(TEXTO_TE_ESPERAN)
	else:
		await mensaje(HistoriaVillaRaiz.texto_rival(TEXTO_RUTA_103))
	terminar(false, [npc])


## LittlerootTown_ProfessorBirchsLab_EventScript_Rival.
func _on_rival_hablado(npc: Node2D) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	npc.mirar_jugador()
	await mensaje(HistoriaVillaRaiz.texto_rival(TEXTO_RIVAL_ADONDE_IR))
	terminar(false, [npc])


## LittlerootTown_ProfessorBirchsLab_EventScript_Aide.
func _on_ayudante_hablado(npc: Node2D) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	npc.mirar_jugador()
	if HistoriaVillaRaiz.estado_laboratorio() >= 3:
		await mensaje(HistoriaVillaRaiz.texto_rival(TEXTO_AYUDA_RIVAL))
	elif SistemaGuardado.get_flag(BANDERA_AYUDANTE):
		await mensaje(TEXTO_NO_ES_DE_MESA)
	else:
		await mensaje(TEXTO_TRABAJO_CAMPO)
		SistemaGuardado.set_flag(BANDERA_AYUDANTE, true)
	terminar(false, [npc])


## Máquinas del laboratorio (sin equivalente en Rubí, donde la Nacional llega por
## intercambio con RF/VH): con la POKéDEX y las 8 MEDALLAS la actualizan al modo
## NACIONAL (FLAG_SYS_NATIONAL_DEX). Si no, solo muestran su texto de cartel.
func _on_maquina(cartel: CartelEvento) -> void:
	if _en_curso:
		return
	if not puede_activar_dex_nacional():
		Singleton.mostrar_texto(tr(cartel.id_texto))
		return
	if not comenzar(_administrador()):
		return
	await mensaje(TEXTO_MAQUINA_NACIONAL, false)
	await mensaje_con_fanfarria(TEXTO_DEX_NACIONAL)
	PokedexPartida.activar_nacional()
	await mensaje(TEXTO_DEX_NACIONAL_EXPLICA)
	terminar()


static func puede_activar_dex_nacional() -> bool:
	return PokedexPartida.obtenida() and not PokedexPartida.nacional_disponible() \
			and SistemaGuardado.contar_medallas() >= MEDALLAS_DEX_NACIONAL


func _comenzar_con(npc: Node2D) -> bool:
	if not comenzar(npc.nodo_administrador):
		if npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	return true
