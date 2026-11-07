## evento_pueblo_azuliza.gd
## Guion del exterior de PUEBLO AZULIZA (pokeruby data/maps/DewfordTown/scripts.inc). El
## SR. ARENQUE y su barca los dirige EventoArenqueAzuliza; aquí solo el pescador.
## Las celdas de Godot son las de Rubí + (6,0).
##
## PESCADOR (objeto 3, DewfordTown_EventScript_OldRodFisherman): lock + faceplayer.
## - Sin la CAÑA VIEJA (FLAG_RECEIVED_OLD_ROD): pregunta SÍ/NO si te pica el gusanillo.
##   NO → «peor para ti». SÍ → te da la CAÑA VIEJA y unos consejos de pesca.
## - Con ella: «¿Cómo va la pesca?» con dos respuestas (multichoice EXCELENTE / NO MUY BIEN):
##   la buena le alegra y la mala le hace repetir los consejos.
extends EventoGuionizado
class_name EventoPuebloAzuliza

const MOTIVO_PAUSA: StringName = &"pueblo_azuliza"

## FLAG_RECEIVED_OLD_ROD.
const BANDERA_CANA_VIEJA: String = "azuliza_cana_vieja_recibida"
## ITEM_OLD_ROD.
const OBJETO_CANA: String = "CANAVIEJA"
const TEXTO_PREGUNTA: String = "AZULIZA_PESCADOR_PREGUNTA"
const TEXTO_CANA: String = "AZULIZA_PESCADOR_CANA"
const TEXTO_CONSEJOS: String = "AZULIZA_PESCADOR_CONSEJOS"
const TEXTO_NO: String = "AZULIZA_PESCADOR_NO"
const TEXTO_COMO_VA: String = "AZULIZA_PESCADOR_COMO_VA"
const TEXTO_GENIAL: String = "AZULIZA_PESCADOR_GENIAL"
const TEXTO_CONSEJO_MAL: String = "AZULIZA_PESCADOR_CONSEJO_MAL"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
const OPCION_EXCELENTE: String = "AZULIZA_OPCION_EXCELENTE"
const OPCION_REGULAR: String = "AZULIZA_OPCION_REGULAR"

@export var pescador: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc := get_node_or_null(pescador)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(_on_pescador)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _on_pescador(npc: Node2D) -> void:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()  # faceplayer
	if SistemaGuardado.get_flag(BANDERA_CANA_VIEJA):
		await _como_va_la_pesca()  # HowsFishing
	elif await preguntar_si_no(TEXTO_PREGUNTA):
		await _dar_cana(npc)  # GiveOldRod
	else:
		await mensaje(TEXTO_NO)  # NotGettingItchToFish
	terminar(false, [npc])


func _dar_cana(npc: Node2D) -> void:
	await mensaje(TEXTO_CANA, false)
	if not await dar_objeto(npc, OBJETO_CANA):
		await mensaje(TEXTO_MOCHILA_LLENA)
		return
	SistemaGuardado.set_flag(BANDERA_CANA_VIEJA, true)
	await mensaje(TEXTO_CONSEJOS)


func _como_va_la_pesca() -> void:
	var opciones := PackedStringArray([tr(OPCION_EXCELENTE), tr(OPCION_REGULAR)])
	if await elegir_opcion(TEXTO_COMO_VA, opciones) == 0:
		await mensaje(TEXTO_GENIAL)  # FishingExcellent
	else:
		await mensaje(TEXTO_CONSEJO_MAL)  # FishingNotSoGood


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
