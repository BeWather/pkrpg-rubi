## evento_ruta_110_camino_bici.gd
## Reto del CAMINO de BICIS de la COSTA en RUTA 110 (pokeruby data/maps/Route110/scripts.inc y
## src/field_specials.c). Complementa a las casetas de entrada (EventoCaminoBici), que dejan
## VAR_CYCLING_CHALLENGE_STATE en 1 al cruzar la NORTE en BICI CARRERA.
##
##   OnTransition (Route110_MapScript1_14F914): estado 1 → savebgm MUS_CYCLING (tema BICICLETA).
##   OnResume (Route110_MapScript1_14F910, UpdateCyclingRoadState): si se viene de cualquier mapa
##       que no sea la caseta NORTE, estado 2 o 3 → 0.
##   OnFrame (Route110_MapScript2_14F933): estado 1 → ScrSpecial_BeginCyclingRoadChallenge
##       (cronómetro y choques a cero) y estado = 2.
##   JUEZ (objeto 21, Route110_EventScript_14FA53): según la bici y el estado.
##   Triggers (28,92) y (29,92) con estado 2 (Route110_EventScript_14FC27): FinishCyclingRoadChallenge,
##       tiempos y puntuación, texto según el resultado, estado = 3 y vuelve la música del mapa.
##   Cartel (32,93) (Route110_EventScript_14FA2E): mejor récord o «no consta ningún récord».
extends EventoGuionizado
class_name EventoRuta110CaminoBici

const MOTIVO_PAUSA: StringName = &"ruta_110_camino_bici"
const ID_JUEZ: StringName = &"juez"
## Mapa de la caseta NORTE: venir de ella conserva el estado del reto.
const MAPA_CASETA_NORTE: String = "ruta_110_entrada_norte"
## MUS_CYCLING.
const TEMA_CICLISMO: String = "BICICLETA"

const TEXTO_JUEZ: String = "RUTA110_JUEZ"
const TEXTO_JUEZ_EN_BICI: String = "RUTA110_JUEZ_EN_BICI"
const TEXTO_JUEZ_TRAS_RETO: String = "RUTA110_JUEZ_TRAS_RETO"
const TEXTO_RESULTADO: String = "RUTA110_JUEZ_RESULTADO"
const TEXTO_SIN_RECORD: String = "RUTA110_10_RECORD"
const TEXTO_RECORD: String = "RUTA110_RECORD_CON_DATOS"

## NPC del JUEZ (objeto 21).
@export var juez: NodePath
## Cartel de récords (bg_event de (32,93)); debe ser un CartelEvento.
@export var cartel_record: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	var npc := get_node_or_null(juez)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_juez_hablado)
	var cartel := get_node_or_null(cartel_record)
	if cartel is CartelEvento:
		cartel.accionado.connect(_on_cartel_record)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)


## OnFrame: con el reto preparado y el mapa ya en pantalla, arranca el cronómetro.
func _process(_delta: float) -> void:
	comenzar_si_preparado()


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## OnTransition y OnResume, en ese orden.
func _on_mapa_activado(_por_warp: bool) -> void:
	preparar_musica()
	actualizar_estado()


## Route110_MapScript1_14F914: con el reto preparado suena MUS_CYCLING al entrar.
func preparar_musica() -> void:
	if CaminoBici.estado_reto() == CaminoBici.RETO_PREPARADO:
		reproducir_musica(TEMA_CICLISMO)


## UpdateCyclingRoadState. Overworld_SetSavedMusic(MUS_DUMMY) no tiene equivalente: no hay
## música guardada que borrar (cada mapa pone su tema al activarse).
func actualizar_estado() -> void:
	var adm := _administrador()
	var anterior: String = str(adm.get("mapa_anterior_key")) if adm != null else ""
	if anterior == MAPA_CASETA_NORTE:
		return
	var estado := CaminoBici.estado_reto()
	if estado == CaminoBici.RETO_EN_CURSO or estado == CaminoBici.RETO_TERMINADO:
		CaminoBici.fijar_estado_reto(CaminoBici.RETO_LIBRE)


## Route110_EventScript_14F93D (map_script_2 VAR_CYCLING_CHALLENGE_STATE, 1). Devuelve true si
## arrancó el reto. Espera a que termine el warp de llegada y a que no haya un guion en curso.
func comenzar_si_preparado() -> bool:
	if _en_curso or CaminoBici.estado_reto() != CaminoBici.RETO_PREPARADO:
		return false
	var adm := _administrador()
	var mapa := obtener_mapa()
	if adm == null or mapa == null or adm.get("mapa_actual") != mapa:
		return false
	if int(adm.get("coneccion")) != 0:
		return false
	CaminoBici.comenzar_reto()  # special ScrSpecial_BeginCyclingRoadChallenge
	CaminoBici.fijar_estado_reto(CaminoBici.RETO_EN_CURSO)
	return true


func _on_disparador(id_evento: StringName) -> void:
	if id_evento == ID_JUEZ:
		await resultados_del_juez()


## Route110_EventScript_14FC27 (coord_event con VAR_CYCLING_CHALLENGE_STATE == 2) y
## Route110_EventScript_14FC39.
func resultados_del_juez() -> void:
	if _en_curso or CaminoBici.estado_reto() != CaminoBici.RETO_EN_CURSO:
		return
	if not comenzar(_administrador()):
		return
	var npc := get_node_or_null(juez) as Node2D
	if npc != null:
		mirar(npc, Vector2.RIGHT)  # walk_in_place_fastest_right
	var datos: Dictionary = CaminoBici.terminar_reto()  # special FinishCyclingRoadChallenge
	await mensaje(TEXTO_RESULTADO, true, {
		"{n}": CaminoBici.texto_choques(int(datos["choques"])),
		"{tiempo}": CaminoBici.texto_tiempo(int(datos["fotogramas"])),
	})
	await mensaje(clave_texto_resultado(int(datos["resultado"])))
	CaminoBici.fijar_estado_reto(CaminoBici.RETO_TERMINADO)
	restaurar_musica_mapa()  # savebgm 0 + fadedefaultbgm
	terminar()


## switch VAR_RESULT: 10, 9-7, 6-4, 3-1 y 0.
static func clave_texto_resultado(resultado: int) -> String:
	if resultado >= 10:
		return "RUTA110_JUEZ_RES_10"
	if resultado >= 7:
		return "RUTA110_JUEZ_RES_7_9"
	if resultado >= 4:
		return "RUTA110_JUEZ_RES_4_6"
	if resultado >= 1:
		return "RUTA110_JUEZ_RES_1_3"
	return "RUTA110_JUEZ_RES_0"


## Route110_EventScript_14FA53: lock + faceplayer. Con BICI ACROBÁTICA (GetPlayerAvatarBike == 1)
## explica que no puntúa; si no, la introducción (estado 0) o el ánimo tras el reto.
func _on_juez_hablado(npc: Node2D) -> void:
	var adm: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(adm):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	await mensaje(clave_texto_juez(CaminoBici.tipo_bici_jugador(admin.get("jugador")), CaminoBici.estado_reto()))
	terminar(false, [npc])


static func clave_texto_juez(bici: int, estado: int) -> String:
	if bici == CaminoBici.BICI_ACROBATICA:
		return TEXTO_JUEZ_EN_BICI
	if estado == CaminoBici.RETO_LIBRE:
		return TEXTO_JUEZ
	return TEXTO_JUEZ_TRAS_RETO


## Route110_EventScript_14FA2E: lockall + GetRecordedCyclingRoadResults.
func _on_cartel_record(_cartel: CartelEvento) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	var registro: Dictionary = CaminoBici.record()
	if registro.is_empty():
		await mensaje(TEXTO_SIN_RECORD)
	else:
		await mensaje(TEXTO_RECORD, true, {
			"{n}": CaminoBici.texto_choques(int(registro["choques"])),
			"{tiempo}": CaminoBici.texto_tiempo(int(registro["fotogramas"])),
		})
	terminar()
