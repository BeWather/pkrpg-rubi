## evento_escuela_ferrica.gd
## Guiones de la ESCUELA de ENTRENADORES POKéMON de CIUDAD FÉRRICA (pokeruby
## data/maps/RustboroCity_PokemonSchool). Las celdas de Godot son las de Rubí.
##
## - PIZARRA (4 carteles en (4..7,2), RustboroCity_PokemonSchool_EventScript_Blackboard):
##   «En la pizarra hay notas…» y un menú con los cinco estados alterados; tras cada
##   explicación vuelve a preguntar hasta elegir SALIR (o cancelar con B).
##   El menú de Rubí es una rejilla (multichoicegrid 3 por fila); aquí es la lista
##   vertical de siempre.
## - PROFESOR (objeto 6, EventScript_Teacher): la primera vez recorre el aula
##   «comprobando a los alumnos» (según hacia dónde mirase el jugador), da la GARRA
##   RÁPIDA y la explica; después solo la explica. Siempre acaba mirando abajo.
extends EventoGuionizado
class_name EventoEscuelaFerrica

const MOTIVO_PAUSA: StringName = &"escuela_ferrica"
const TipoMovimiento := NpcBase.TipoMovimientoNPC

const T := "FERRICA_ESCUELA_"
const TEXTO_PIZARRA: String = T + "PIZARRA"
const TEXTO_TEMA: String = T + "TEMA"
const TEXTO_GARRA: String = T + "PROFESOR_GARRA"
const TEXTO_EXPLICA: String = T + "PROFESOR_EXPLICA"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
const OBJETO_GARRA_RAPIDA: String = "GARRARAPIDA"

## Opciones del menú, en el orden de MultichoiceList_13: [etiqueta, texto]. La
## última (SALIR) no tiene texto. Las etiquetas salen del decomp en español.
const TEMAS := [
	[T + "OP_VENENO", T + "VENENO"],
	[T + "OP_PARALISIS", T + "PARALISIS"],
	[T + "OP_SUENO", T + "SUENO"],
	[T + "OP_QUEMADURA", T + "QUEMADURA"],
	[T + "OP_CONGELACION", T + "CONGELACION"],
	[T + "OP_SALIR", ""],
]

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN
## Pasos del PROFESOR: Vector2 = camina, String (MIRA_*) = se gira sin moverse,
## int = fotogramas de espera. Ver _recorrido().
const MIRA_ABAJO := "abajo"
const MIRA_IZQUIERDA := "izquierda"
## TeacherCheckOnStudentsEast (el jugador mira al este, VAR_FACING 4).
static var RECORRIDO_ESTE: Array = [R, R, D, D, L, L, MIRA_ABAJO, 16, 16, 16, D, MIRA_IZQUIERDA,
	16, 16, R, 16, 16, 8, U, R, U, U, L, L]
## TeacherCheckOnStudentsWest (el jugador mira al oeste, VAR_FACING 3).
static var RECORRIDO_OESTE: Array = [L, D, D, R, MIRA_ABAJO, 16, 16, 16, D, MIRA_IZQUIERDA,
	16, 16, R, 16, 16, 8, U, L, L, U, U, R]

@export var pizarras: Array[NodePath] = []
@export var profesor: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for ruta in pizarras:
		var cartel := get_node_or_null(ruta)
		if cartel is CartelEvento:
			cartel.accionado.connect(_on_pizarra)
	var npc := _npc(profesor)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_profesor_hablado)


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## ============================================================================
## PIZARRA
## ============================================================================

## lockall + msgbox + bucle de ChooseBlackboardTopic.
func _on_pizarra(_cartel: CartelEvento) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	await mensaje(TEXTO_PIZARRA)
	while true:
		var etiquetas := PackedStringArray()
		for tema: Array in TEMAS:
			etiquetas.append(tr(tema[0]))
		var elegido := await elegir_opcion(TEXTO_TEMA, etiquetas)
		var clave: String = TEMAS[elegido][1]
		if clave.is_empty():  # ExitTopicSelect (SALIR o B)
			break
		await mensaje(clave)
	terminar()


## multichoice: índice de la opción elegida (cancelar = la última). Con dos opciones el
## menú responde "Y" / "N"; con más, el índice.
func elegir_opcion(clave: String, opciones: PackedStringArray) -> int:
	var dialogo: NinePatchRect = admin.cuadro_dialogo
	dialogo.cerrar()
	dialogo.preguntaSiNo(tr(clave), opciones)
	while true:
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			var respuesta := str(parametros[0]) if not parametros.is_empty() else "N"
			if respuesta == "Y":
				return 0
			if respuesta.is_valid_int():
				return clampi(int(respuesta), 0, opciones.size() - 1)
			return opciones.size() - 1
	return opciones.size() - 1


## ============================================================================
## PROFESOR
## ============================================================================

## RustboroCity_PokemonSchool_EventScript_Teacher (lock + faceplayer).
func _on_profesor_hablado(npc: Node2D) -> void:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	var mirada: Vector2 = npc.jugador.facing_direction if npc.jugador != null else D
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	if SistemaGuardado.get_flag(HistoriaFerrica.BANDERA_GARRA_RAPIDA):
		await mensaje(TEXTO_EXPLICA)  # GaveQuickClaw
		mirar(npc, D)
		terminar(false, [npc])
		return
	if mirada == R:
		await _recorrido(npc, RECORRIDO_ESTE)
	elif mirada == L:
		await _recorrido(npc, RECORRIDO_OESTE)
	await mensaje(TEXTO_GARRA, false)
	if not await dar_objeto(npc, OBJETO_GARRA_RAPIDA):
		await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
		terminar(false, [npc])
		return
	admin.cuadro_dialogo.cerrar()  # closemessage
	mirar(npc, D)
	SistemaGuardado.set_flag(HistoriaFerrica.BANDERA_GARRA_RAPIDA, true)
	terminar(false, [npc])


func _recorrido(npc: Node2D, pasos: Array) -> void:
	for paso in pasos:
		if paso is Vector2:
			await caminar(npc, paso)
		elif paso is int:
			await esperar_fotogramas(paso)
		elif paso == MIRA_ABAJO:
			mirar(npc, D)
		elif paso == MIRA_IZQUIERDA:
			mirar(npc, L)
