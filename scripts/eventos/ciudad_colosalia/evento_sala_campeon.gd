## evento_sala_campeon.gd
## Sala del CAMPEÓN de la LIGA POKéMON (pokeruby EverGrandeCity_ChampionsRoom/scripts.inc). MÁXIMO (STEVEN)
## en (6,5); el rival (VAR_0: AURA para un chico, BRUNO para una chica) y el PROF. ABEDUL esperan ocultos en
## la entrada (6,12).
##
## OnFrame al entrar (VAR_TEMP_1 = 0): el jugador mira al norte, sube cuatro casillas, delay 40 y dos más
## hasta MÁXIMO; playbgm MUS_ENCOUNTER_CHAMPION, presentación y trainerbattle_no_intro TRAINER_STEVEN. Al
## ganar: SE_DOOR y se abre la puerta del norte (setmetatile 0x346/0x347), discurso de MÁXIMO; SE_DOOR y
## llega el rival con su música (MUS_ENCOUNTER_MAY/BRENDAN), da su consejo, se sorprende («!»), mira a un
## lado y a otro y se da cuenta de que ya está. Entra ABEDUL, valora la POKéDEX (ProfBirch_EventScript_
## RatePokedex: vistos y atrapados de HOENN y, con la NACIONAL, los nacionales; sin el comentario según la
## cifra) y felicita. MÁXIMO pide que le sigan, el rival se queda fuera con el PROFESOR, y MÁXIMO y el
## jugador salen por la puerta norte (set_invisible) hacia el SALÓN DE LA FAMA (warp 255, 7, 16).
## Perder reinicia el ALTO MANDO (EventScript_WhiteOut). FLAG_HIDE_PETALBURG_GYM_GUIDE no se migra.
extends EventoInteriorMalvalona
class_name EventoSalaCampeon

const MOTIVO_PAUSA: StringName = &"sala_campeon"

## TRAINER_STEVEN.
const ENTRENADOR_MAXIMO: int = 335
const MUSICA_ENCUENTRO: String = "ENCUENTRO_CAMPEON"
const SONIDO_PUERTA: String = "puerta_entrada"  # SE_DOOR
const SONIDO_EXCLAMACION: String = "SE_PIN"
const METATILE_PUERTA_MARCO: int = 0x346
const METATILE_PUERTA_ABIERTA: int = 0x347
const CELDA_MARCO: Vector2i = Vector2i(6, 1)
const CELDA_PUERTA: Vector2i = Vector2i(6, 2)
## Donde aparecen el rival y ABEDUL (sus object_events).
const CELDA_ENTRADA: Vector2i = Vector2i(6, 12)
const CELDA_MAXIMO: Vector2i = Vector2i(6, 5)
const MAPA_SALON: String = "ciudad_colosalia_salon_fama"
const CELDA_SALON: Vector2i = Vector2i(7, 16)

const T := "COLOSALIA_CAMPEON_"
const TEXTO_INTRO: String = T + "MAXIMO_INI"
const TEXTO_POST: String = T + "MAXIMO_POST"
const TEXTO_ABEDUL_POKEDEX: String = T + "ABEDUL_POKEDEX"
const TEXTO_ABEDUL_FELICIDADES: String = T + "ABEDUL_FELICIDADES"
const TEXTO_POKEDEX_HOENN: String = T + "POKEDEX_HOENN"
const TEXTO_POKEDEX_NACIONAL: String = T + "POKEDEX_NACIONAL"
const TEXTO_ACOMPANAME: String = T + "MAXIMO_ACOMPANAME"
const TEXTO_ESPERAD: String = T + "MAXIMO_ESPERAD"

@export var maximo: NodePath
@export var rival: NodePath
@export var abedul: NodePath
@export var suelo: NodePath
@export var superior: NodePath
@export var datos_tiles: NodePath

## Estado original de la puerta norte: celda -> [abajo, arriba, banderas].
var _originales: Dictionary = {}


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var capa_suelo := nodo(suelo) as TileMapLayer
	var capa_superior := nodo(superior) as TileMapLayer
	var tp := nodo(datos_tiles) as TPTileDataMap
	for celda in [CELDA_MARCO, CELDA_PUERTA]:
		_originales[celda] = [
			capa_suelo.get_cell_atlas_coords(celda) if capa_suelo != null else Vector2i(-1, -1),
			capa_superior.get_cell_atlas_coords(celda) if capa_superior != null else Vector2i(-1, -1),
			tp.get_flags(Vector2(celda)) if tp != null else 0,
		]
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar()


func _on_mapa_activado(por_warp: bool) -> void:
	preparar()
	if por_warp:
		await escena()


## La sala como al cargarla: MÁXIMO en su sitio, rival y ABEDUL ocultos y la puerta norte cerrada.
func preparar() -> void:
	if _en_curso:
		return
	var steven := nodo(maximo)
	if steven != null:
		steven.visible = true
		colocar(steven, CELDA_MAXIMO)
		mirar(steven, D)
	for ruta in [rival, abedul]:
		var npc := nodo(ruta)
		if npc != null:
			colocar(npc, CELDA_ENTRADA)
			npc.visible = false
	for celda: Vector2i in _originales:
		var original: Array = _originales[celda]
		EventoSalaAltoMando._restaurar_celda(nodo(suelo) as TileMapLayer, celda, original[0])
		EventoSalaAltoMando._restaurar_celda(nodo(superior) as TileMapLayer, celda, original[1])
		var tp := nodo(datos_tiles) as TPTileDataMap
		if tp != null and int(original[2]) & TPTileDataMap.Flags.BLOQUEO:
			tp.set_flag(Vector2(celda), TPTileDataMap.Flags.BLOQUEO)


## EverGrandeCity_ChampionsRoom_EventScript_EnterRoom y siguientes.
func escena() -> void:
	if not comenzar(_administrador()):
		return
	await esperar_fin_warp(admin)
	var steven := nodo(maximo)
	girar_jugador(U)  # OnWarp
	await recorrer_jugador([U, U, U, U])  # Common_Movement_WalkUp4
	await esperar_fotogramas(40)
	await recorrer_jugador([U, U])
	steven.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	reproducir_musica(MUSICA_ENCUENTRO)
	await mensaje(TEXTO_INTRO)
	var resultado := await combatir(ENTRENADOR_MAXIMO)
	if resultado != &"victoria":
		if resultado == &"derrota_transferida":
			EventoSalaAltoMando.reiniciar_alto_mando()
		terminar(resultado == &"derrota_transferida", [steven])
		return
	await tras_la_victoria(steven)


## EverGrandeCity_ChampionsRoom_EventScript_Defeated.
func tras_la_victoria(steven: Node2D) -> void:
	Singleton.play_sound.emit(SONIDO_PUERTA)
	abrir_puerta_norte()
	await mensaje(TEXTO_POST)
	admin.cuadro_dialogo.cerrar()  # closemessage
	Singleton.play_sound.emit(SONIDO_PUERTA)
	reproducir_musica(Rival.musica_encuentro())
	var npc_rival := nodo(rival)
	var clave := Rival.clave()
	colocar(npc_rival, CELDA_ENTRADA)
	npc_rival.visible = true  # addobject 2
	npc_rival.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	# EverGrandeCity_ChampionsRoom_Movement_RivalApproachPlayer.
	await recorrer(npc_rival, [U, U, U, U, U, L, U])
	mirar(npc_rival, R)
	girar_jugador(L)
	await mensaje(T + clave + "_CONSEJO")
	await esperar_fotogramas(40)
	Singleton.play_sound.emit(SONIDO_EXCLAMACION)
	await exclamacion(npc_rival)
	await esperar_fotogramas(48)
	await mirar_a_un_lado_y_a_otro(npc_rival)
	await mensaje(T + clave + "_YA_ESTA")
	admin.cuadro_dialogo.cerrar()

	# EverGrandeCity_ChampionsRoom_EventScript_BirchArrivesExitForHoF.
	var npc_abedul := nodo(abedul)
	colocar(npc_abedul, CELDA_ENTRADA)
	npc_abedul.visible = true  # addobject 3
	npc_abedul.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	await recorrer(npc_abedul, [U, U, U, U, U, R, U])
	mirar(npc_abedul, L)
	girar_jugador(R)
	await mensaje(TEXTO_ABEDUL_POKEDEX, true, {"{rival}": clave})
	await valorar_pokedex()
	await mensaje(TEXTO_ABEDUL_FELICIDADES)
	mirar(steven, U)
	await esperar_fotogramas(20)
	mirar(steven, D)
	await mensaje(TEXTO_ACOMPANAME)
	admin.cuadro_dialogo.cerrar()
	await esperar_fotogramas(30)
	mirar(npc_abedul, U)
	await en_paralelo([recorrer.bind(steven, [U, U]), recorrer_jugador.bind([U, U])])
	mirar(steven, D)
	await recorrer(npc_rival, [R, U])  # EverGrandeCity_ChampionsRoom_Movement_RivalFollows
	await esperar_fotogramas(20)
	girar_jugador(D)
	await mensaje(TEXTO_ESPERAD)
	await mensaje(T + clave + "_FELICIDADES")
	admin.cuadro_dialogo.cerrar()
	await en_paralelo([_salir_maximo.bind(steven), _salir_jugador])
	_ir_al_salon([steven, npc_rival, npc_abedul])


## EverGrandeCity_ChampionsRoom_Movement_RivalLookBackAndForth.
func mirar_a_un_lado_y_a_otro(npc: Node2D) -> void:
	for paso in [[U, 16], [R, 16], [U, 8], [R, 16]]:
		mirar(npc, paso[0])
		await esperar_fotogramas(paso[1])


## ProfBirch_EventScript_RatePokedex (sin ProfBirch_EventScript_ShowRatingMessage).
func valorar_pokedex() -> void:
	var cuentas := EventoSalaCampeon.contar_pokedex()
	await mensaje(TEXTO_POKEDEX_HOENN, true, {"{vistos}": cuentas[0], "{atrapados}": cuentas[1]})
	if PokedexPartida.nacional_disponible():
		await mensaje(TEXTO_POKEDEX_NACIONAL, true, {"{vistos}": cuentas[2], "{atrapados}": cuentas[3]})


## ScriptGetPokedexInfo: [vistos HOENN, atrapados HOENN, vistos NACIONAL, atrapados NACIONAL].
static func contar_pokedex() -> Array[int]:
	var res: Array[int] = [0, 0, 0, 0]
	for registro in PokedexPartida.crear_registros():
		var hoenn := int(registro.get("numero", 0)) > 0
		if registro.get("visto", false):
			res[2] += 1
			if hoenn:
				res[0] += 1
		if registro.get("atrapado", false):
			res[3] += 1
			if hoenn:
				res[1] += 1
	return res


## setmetatile 6, 1, METATILE_EliteFour_OpenDoorChampion_Frame + 6, 2, _Opening (pasables).
func abrir_puerta_norte() -> void:
	var capa_suelo := nodo(suelo) as TileMapLayer
	var capa_superior := nodo(superior) as TileMapLayer
	var tp := nodo(datos_tiles) as TPTileDataMap
	EventoSalaAltoMando.pintar_metatile(capa_suelo, capa_superior, tp, CELDA_MARCO, METATILE_PUERTA_MARCO, false)
	EventoSalaAltoMando.pintar_metatile(capa_suelo, capa_superior, tp, CELDA_PUERTA, METATILE_PUERTA_ABIERTA, false)


## EverGrandeCity_ChampionsRoom_Movement_StevenExitStart + _StevenExit.
func _salir_maximo(steven: Node2D) -> void:
	await caminar(steven, U)
	await esperar_fotogramas(8)
	steven.visible = false


## EverGrandeCity_ChampionsRoom_Movement_PlayerExit.
func _salir_jugador() -> void:
	await recorrer_jugador([U])
	await esperar_fotogramas(16)
	await recorrer_jugador([U])
	await esperar_fotogramas(8)
	admin.jugador.visible = false


## warp MAP_EVER_GRANDE_CITY_HALL_OF_FAME, 255, 7, 16.
func _ir_al_salon(npcs: Array) -> void:
	var jugador: Node = admin.jugador
	var admin_actual: Node = admin
	terminar(true, npcs)  # solo suelta la pausa del guion: el warp conserva el control
	jugador.end_dialog()
	jugador.no_control = true
	admin_actual.conectar_escalera(MAPA_SALON, Vector2(CELDA_SALON), Vector2.UP, false, true)
