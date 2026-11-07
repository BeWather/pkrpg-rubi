## evento_casa_buscatesoros.gd
## CASA del BUSCATESOROS MARINOS de la RUTA 124 (pokeruby Route124_DivingTreasureHuntersHouse). Godot = Rubí.
##
## BUSCATESOROS (objeto 1, MAN_6 en (5,4), FACE_LEFT; `lock` + FacePlayer): la primera vez se presenta y activa
## FLAG_MET_DIVING_TREASURE_HUNTER; después solo pregunta si has visto alguna PARTE. Sin PARTES (ni la ROJA, ni la
## AMARILLA, ni la AZUL, ni la VERDE) dice que le avises; con alguna se emociona y abre el menú «¿Qué quieres
## cambiar?» con las PARTES que lleves (en el orden de Rubí: roja, amarilla, azul y verde) y SALIR. Elegir una
## pregunta «¿Me cambiarías tu PARTE por mi PIEDRA?» (SÍ/NO): NO o SALIR → «¿No? Qué aguafiestas...»; SÍ → si la
## PIEDRA no cabe en la mochila, «la MOCHILA está llena» y se acaba; si no, cambia 1 PARTE por 1 PIEDRA
## (ROJA → FUEGO, AMARILLA → TRUENO, AZUL → AGUA, VERDE → HOJA), «¡Trato hecho!» y, mientras queden PARTES,
## «¿Quieres cambiar algo más?» (SÍ vuelve al menú, NO → «¿No? Qué aguafiestas...»).
## El cartel de (7,1) es una tabla de equivalencias (texto de la ROM sin el alineado por columnas).
## FLAG_LANDMARK_HUNTERS_HOUSE la activa BanderasLandmark al entrar en la escena.
extends EventoInteriorMalvalona
class_name EventoCasaBuscatesoros

const MOTIVO_PAUSA: StringName = &"casa_buscatesoros"

## FLAG_MET_DIVING_TREASURE_HUNTER.
const BANDERA_CONOCIDO: String = "ruta124_buscatesoros_conocido"
## Parte pedida → piedra que da, en el orden de los menús de Rubí (VAR_TEMP_1: 1, 2, 4, 8).
const TRUEQUES: Array[Array] = [
	["PARTEROJA", "PIEDRAFUEGO"],
	["PAMARILLA", "PIEDRATRUENO"],
	["PARTEAZUL", "PIEDRAAGUA"],
	["PARTEVERDE", "PIEDRAHOJA"],
]

const T := "RUTA124_CASA_BUSCATESOROS_"
const TEXTO_INTRO: String = T + "INTRO"
const TEXTO_PREGUNTA: String = T + "PREGUNTA"
const TEXTO_SIN_PARTES: String = T + "SIN_PARTES"
const TEXTO_PARTE_VISTA: String = T + "PARTE_VISTA"
const TEXTO_QUE_CAMBIAR: String = T + "QUE_CAMBIAR"
const TEXTO_CONFIRMAR: String = T + "CONFIRMAR"
const TEXTO_HECHO: String = T + "HECHO"
const TEXTO_OTRO: String = T + "OTRO"
const TEXTO_MOCHILA_LLENA_BUSCATESOROS: String = T + "MOCHILA_LLENA"
const TEXTO_NO: String = T + "NO"
const OPCION_SALIR: String = "RUTA124_CASA_OPCION_SALIR"

@export var buscatesoros: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(buscatesoros, _on_buscatesoros)


static func _bolsillo(objeto: String) -> int:
	return int(SistemaGuardado.obtener_datos_objeto_completos(objeto).get("bolsillo_id", 0))


static func _nombre_objeto(objeto: String) -> String:
	return str(SistemaGuardado.obtener_datos_objeto_completos(objeto).get("nombre", objeto))


## Índices de TRUEQUES cuya PARTE lleva el jugador (el VAR_TEMP_1 del script, en lista).
static func partes_que_lleva() -> Array[int]:
	var indices: Array[int] = []
	for i in TRUEQUES.size():
		var parte: String = TRUEQUES[i][0]
		if SistemaGuardado.get_cantidad_objeto(parte, _bolsillo(parte)) >= 1:
			indices.append(i)
	return indices


## Route124_DivingTreasureHuntersHouse_EventScript_163E04.
func _on_buscatesoros(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if SistemaGuardado.get_flag(BANDERA_CONOCIDO):
		await mensaje(TEXTO_PREGUNTA)
	else:
		await mensaje(TEXTO_INTRO)
		SistemaGuardado.set_flag(BANDERA_CONOCIDO, true)
	await _ofrecer_trueque(npc)
	terminar(false, [npc])


## EventScript_163E2E: sin PARTES, aviso; con alguna, el menú de trueques (EventScript_163EB0).
func _ofrecer_trueque(npc: Node2D) -> void:
	if partes_que_lleva().is_empty():
		await mensaje(TEXTO_SIN_PARTES)
		return
	await mensaje(TEXTO_PARTE_VISTA)
	while true:
		var disponibles: Array[int] = partes_que_lleva()
		var opciones := PackedStringArray()
		for indice in disponibles:
			opciones.append(_nombre_objeto(TRUEQUES[indice][0]))
		opciones.append(tr(OPCION_SALIR))
		var elegida: int = await elegir_opcion(TEXTO_QUE_CAMBIAR, opciones)
		if elegida >= disponibles.size():
			await mensaje(TEXTO_NO)
			return
		var parte: String = TRUEQUES[disponibles[elegida]][0]
		var piedra: String = TRUEQUES[disponibles[elegida]][1]
		var nombres := {"{parte}": _nombre_objeto(parte), "{piedra}": _nombre_objeto(piedra)}
		if not await preguntar_si_no(TEXTO_CONFIRMAR, nombres):
			await mensaje(TEXTO_NO)
			return
		if not await _cambiar(npc, parte, piedra):
			await mensaje(TEXTO_MOCHILA_LLENA_BUSCATESOROS)
			return
		await mensaje(TEXTO_HECHO)
		if partes_que_lleva().is_empty():
			return
		if not await preguntar_si_no(TEXTO_OTRO):
			await mensaje(TEXTO_NO)
			return


## EventScript_1642D3: takeitem parte + giveitem_std piedra. Sin el checkitemspace de Ruby:
## false (sin tocar la mochila) sólo si no se pudo entregar.
func _cambiar(npc: Node2D, parte: String, piedra: String) -> bool:
	if not SistemaGuardado.quitar_objeto_jugador(parte, 1, _bolsillo(parte)):
		return false
	if not await dar_objeto(npc, piedra):
		SistemaGuardado.dar_objeto_jugador(parte)
		return false
	return true
