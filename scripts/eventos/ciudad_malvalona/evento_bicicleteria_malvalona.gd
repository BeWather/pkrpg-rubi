## evento_bicicleteria_malvalona.gd
## Guiones de la BICICLETERÍA de CIUDAD MALVALONA (pokeruby
## data/maps/MauvilleCity_BikeShop).
##
## ANACLETO (Rydel): sin bici (FLAG_RECEIVED_BIKE) pregunta si el jugador viene de
## lejos; con SÍ le da a elegir entre la BICI CARRERA y la BICI ACROBÁTICA (el objeto
## clave que recibe es la elección; no hay variable aparte), y registra el cambio en
## SELECT (SwapRegisteredBike). Con NO se queda con FLAG_DECLINED_BIKE y la próxima vez
## no repite el saludo. Con bici ya entregada ofrece cambiarla por la otra; si no tiene
## ninguna de las dos (está en el PC) lo dice y no hace nada.
##
## Los dos manuales (bg_event): pregunta «¿Qué capítulo quieres leer?» con tres
## capítulos y SALIR; tras leer uno vuelve al menú. B equivale a SALIR.
##
## El cambio de BICI no lleva la estadística GAME_STAT_TRADED_BIKES (el proyecto no tiene
## estadísticas de partida).
extends EventoInteriorMalvalona
class_name EventoBicicleteriaMalvalona

const MOTIVO_PAUSA: StringName = &"bicicleteria_malvalona"

const T := "CIUDAD_MALVALONA_BICICLETERIA_"
const TEXTO_SALUDO: String = T + "ANACLETO_SALUDO"
const TEXTO_LEJOS: String = T + "ANACLETO_LEJOS"
const TEXTO_NO_NECESITAS: String = T + "ANACLETO_NO_NECESITAS"
const TEXTO_ELIGE: String = T + "ANACLETO_ELIGE"
const TEXTO_ELIGIO_CARRERA: String = T + "ELIGIO_CARRERA"
const TEXTO_ELIGIO_ACROBATICA: String = T + "ELIGIO_ACROBATICA"
const TEXTO_VUELVE: String = T + "ANACLETO_VUELVE"
const TEXTO_CAMBIAR: String = T + "ANACLETO_CAMBIAR"
const TEXTO_CAMBIO_OK: String = T + "ANACLETO_CAMBIO_OK"
const TEXTO_CAMBIO_A_ACROBATICA: String = T + "CAMBIO_A_ACROBATICA"
const TEXTO_CAMBIO_A_CARRERA: String = T + "CAMBIO_A_CARRERA"
const TEXTO_ME_ALEGRO: String = T + "ANACLETO_ME_ALEGRO"
const TEXTO_BICI_EN_PC: String = T + "ANACLETO_BICI_EN_PC"
const TEXTO_MANUAL_CARRERA: String = T + "MANUAL_CARRERA"
const TEXTO_MANUAL_ACROBATICA: String = T + "MANUAL_ACROBATICA"
const ETIQUETAS_BICIS: Array[String] = [
	"CIUDAD_MALVALONA_MENU_BICI_CARRERA", "CIUDAD_MALVALONA_MENU_BICI_ACROBATICA",
]
const TEXTO_SALIR: String = "CIUDAD_MALVALONA_MENU_SALIR"
## [etiqueta del menú, texto del capítulo] de cada manual (el cuarto elemento del menú es
## SALIR).
const CAPITULOS_CARRERA: Array = [
	["CIUDAD_MALVALONA_MENU_CARRERA_MONTAR", T + "CARRERA_MONTAR"],
	["CIUDAD_MALVALONA_MENU_CARRERA_GIRAR", T + "CARRERA_GIRAR"],
	["CIUDAD_MALVALONA_MENU_CARRERA_CUESTAS", T + "CARRERA_CUESTAS"],
]
const CAPITULOS_ACROBATICA: Array = [
	["CIUDAD_MALVALONA_MENU_ACRO_CABALLITO", T + "ACRO_CABALLITO"],
	["CIUDAD_MALVALONA_MENU_ACRO_SALTITOS", T + "ACRO_SALTITOS"],
	["CIUDAD_MALVALONA_MENU_ACRO_SALTAR", T + "ACRO_SALTAR"],
]

@export var anacleto: NodePath
@export var manual_carrera: NodePath
@export var manual_acrobatica: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(anacleto, _on_anacleto)
	for ruta in [manual_carrera, manual_acrobatica]:
		var cartel := nodo(ruta)
		if cartel is CartelEvento:
			cartel.accionado.connect(_on_manual.bind(ruta == manual_carrera))


## MauvilleCity_BikeShop_EventScript_Rydel.
func _on_anacleto(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if SistemaGuardado.get_flag(HistoriaMalvalona.BANDERA_BICI_RECIBIDA):
		await _preguntar_cambio(npc)  # AskSwitchBikes
		return
	if not SistemaGuardado.get_flag(HistoriaMalvalona.BANDERA_BICI_RECHAZADA):
		await mensaje(TEXTO_SALUDO)
	if not await preguntar_si_no(TEXTO_LEJOS):
		SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_BICI_RECHAZADA, true)  # NotFar
		await mensaje(TEXTO_NO_NECESITAS)
		terminar(false, [npc])
		return
	SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_BICI_RECIBIDA, true)  # YesFar
	var opciones := PackedStringArray()
	for etiqueta in ETIQUETAS_BICIS:
		opciones.append(tr(etiqueta))
	var elegida := await elegir_opcion(TEXTO_ELIGE, opciones)
	var carrera := elegida == 0
	await mensaje(TEXTO_ELIGIO_CARRERA if carrera else TEXTO_ELIGIO_ACROBATICA, false)
	var objeto := HistoriaMalvalona.OBJETO_BICI_CARRERA if carrera else HistoriaMalvalona.OBJETO_BICI_ACROBATICA
	if not await dar_objeto(npc, objeto):
		# Rubí no lo trata (giveitem sin comprobar); aquí se deja repetir la elección.
		SistemaGuardado.set_flag(HistoriaMalvalona.BANDERA_BICI_RECIBIDA, false)
		await mensaje_mochila_llena()
		terminar(false, [npc])
		return
	await _despedida(npc)


## ComeBackToSwitchBikes: texto y SwapRegisteredBike.
func _despedida(npc: Node2D) -> void:
	await mensaje(TEXTO_VUELVE)
	HistoriaMalvalona.cambiar_bici_registrada()
	terminar(false, [npc])


## AskSwitchBikes / SwitchBikes.
func _preguntar_cambio(npc: Node2D) -> void:
	if not await preguntar_si_no(TEXTO_CAMBIAR):
		await mensaje(TEXTO_ME_ALEGRO)  # KeepBike
		terminar(false, [npc])
		return
	await mensaje(TEXTO_CAMBIO_OK)
	var tiene_acrobatica := HistoriaMalvalona.tiene(HistoriaMalvalona.OBJETO_BICI_ACROBATICA)
	var tiene_carrera := HistoriaMalvalona.tiene(HistoriaMalvalona.OBJETO_BICI_CARRERA)
	if not tiene_acrobatica and not tiene_carrera:
		await mensaje(TEXTO_BICI_EN_PC)  # OhYourBikeIsInPC
		terminar(false, [npc])
		return
	# Con las dos, Rubí cambia la ACROBÁTICA por la CARRERA (se comprueba primero).
	var a_carrera := tiene_acrobatica
	await mensaje(TEXTO_CAMBIO_A_CARRERA if a_carrera else TEXTO_CAMBIO_A_ACROBATICA, false)
	HistoriaMalvalona.quitar(HistoriaMalvalona.OBJETO_BICI_ACROBATICA if a_carrera else HistoriaMalvalona.OBJETO_BICI_CARRERA)
	await dar_objeto(npc, HistoriaMalvalona.OBJETO_BICI_CARRERA if a_carrera else HistoriaMalvalona.OBJETO_BICI_ACROBATICA)
	await _despedida(npc)


## MachBikeHandbook / AcroBikeHandbook.
func _on_manual(_cartel: CartelEvento, es_carrera: bool) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	var capitulos: Array = CAPITULOS_CARRERA if es_carrera else CAPITULOS_ACROBATICA
	var opciones := PackedStringArray()
	for capitulo: Array in capitulos:
		opciones.append(tr(capitulo[0]))
	opciones.append(tr(TEXTO_SALIR))
	var texto := TEXTO_MANUAL_CARRERA if es_carrera else TEXTO_MANUAL_ACROBATICA
	while true:
		var elegido := await elegir_opcion(texto, opciones)
		if elegido >= capitulos.size():  # SALIR o B
			break
		texto = capitulos[elegido][1]
	terminar()
