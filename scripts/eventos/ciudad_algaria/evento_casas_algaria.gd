## evento_casas_algaria.gd
## Guiones de tres casas de CIUDAD ALGARIA (MOSSDEEP de Rubí). Cada escena asigna solo el NPC que tiene.
##
## - CASA 2 (MossdeepCity_House1), HOMBRE de los POKéCUBOS (BLACK_BELT): «¡Ajá! A tu {POKéMON}...» y, según la
##   naturaleza del primer POKéMON del equipo que no sea un HUEVO, el POKéCUBO que más le gusta (sub_810CB68: el
##   primer sabor, en el orden ROJO, AZUL, ROSA, VERDE, AMARILLO, cuya ganancia con esa naturaleza es positiva) o que
##   le da igual (naturaleza neutra). La naturaleza «gusta» del sabor de la característica que sube: ATAQUE → ROJO
##   (picante), ATAQUE ESPECIAL → AZUL (seco), VELOCIDAD → ROSA (dulce), DEFENSA ESPECIAL → VERDE (amargo) y
##   DEFENSA → AMARILLO (ácido), igual que gPokeblockFlavorCompatibilityTable.
## - CASA 4 (MossdeepCity_House4), CHICO de las BASES SECRETAS: con una base propia pregunta si la hiciste en
##   «{lugar}» (GetSecretBaseNearbyMapName: la sección del mapa de la entrada); sin ella te anima a hacer una.
## - CASA 6 (MossdeepCity_House2), WINGULL: aparece cuando el CHICO de CIUDAD ARBORADA lo manda de recado
##   (FLAG_WINGULL_SENT_ON_ERRAND ≡ `arborada_wingull_enviado`, que sustituye a limpiar
##   FLAG_HIDE_WINGULL_MOSSDEEP_HOUSE). Al hablarle: grito, «WINGULL: ¡Guliii!», entrega el correo
##   (FLAG_WINGULL_DELIVERED_MAIL ≡ `arborada_correo_entregado`), su WINGULL de ARBORADA vuelve
##   (FLAG_HIDE_WINGULL_FORTREE_HOUSE ≡ `arborada_wingull_fuera` desactivada) y se va por la puerta: si mirabas
##   arriba rodea por la derecha (derecha, abajo, abajo, izquierda, abajo), si mirabas a la izquierda baja tres casillas
##   y en otro caso desaparece sin moverse; después se queda oculto.
extends EventoInteriorMalvalona
class_name EventoCasasAlgaria

const MOTIVO_PAUSA: StringName = &"casas_algaria"
const CintaEsfuerzo = preload("res://scripts/npc/npc_cinta_esfuerzo.gd")

const T2 := "ALGARIA_CASA2_"
const TEXTO_EXPERTO_INTRO: String = T2 + "EXPERTO_INTRO"
const TEXTO_EXPERTO_GUSTA: String = T2 + "EXPERTO_GUSTA"
const TEXTO_EXPERTO_IGUAL: String = T2 + "EXPERTO_IGUAL"
## Nombres de los POKéCUBOS por sabor (0 = picante … 4 = ácido): ROJO, AZUL, ROSA, VERDE, AMARILLO.
const CUBOS: Array[String] = [
	T2 + "CUBO_ROJO", T2 + "CUBO_AZUL", T2 + "CUBO_ROSA", T2 + "CUBO_VERDE", T2 + "CUBO_AMARILLO",
]
const TEXTO_CHICO_BASE: String = "ALGARIA_CASA4_CHICO_BASE"
const TEXTO_CHICO_SIN_BASE: String = "ALGARIA_CASA4_CHICO_SIN_BASE"
const TEXTO_WINGULL: String = "ALGARIA_CASA6_WINGULL"

## MossdeepCity_House2_Movement_15A8C4 (mirando arriba) y _15A8CB (mirando a la izquierda).
const SALIDA_MIRANDO_ARRIBA: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.DOWN, Vector2.LEFT, Vector2.DOWN]
const SALIDA_MIRANDO_IZQUIERDA: Array[Vector2] = [Vector2.DOWN, Vector2.DOWN, Vector2.DOWN]
## delay_8.
const FOTOGRAMAS_ESPERA_SALIDA: int = 8

@export var experto: NodePath
@export var chico_base: NodePath
@export var wingull: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(experto, _on_experto)
	escuchar(chico_base, _on_chico_base)
	escuchar(wingull, _on_wingull)


## ============================================================================
## CASA 2: el experto en POKéCUBOS
## ============================================================================

## Sabor (0..4, índice de CUBOS) que le gusta a una naturaleza según la característica que sube; -1 si es
## neutra o no se conoce.
static func sabor_de_estadistica(estadistica: String) -> int:
	match estadistica.strip_edges().to_lower():
		"ataque":
			return 0
		"ataque_especial":
			return 1
		"velocidad":
			return 2
		"defensa_especial":
			return 3
		"defensa":
			return 4
	return -1


## Sabor que le gusta a la naturaleza `naturaleza` (nombre de la tabla Naturalezas); -1 si ninguno.
static func sabor_preferido(naturaleza: String) -> int:
	if naturaleza.strip_edges().is_empty():
		return -1
	var datos: Dictionary = DatabaseManager.obtener_datos_naturaleza(naturaleza)
	return sabor_de_estadistica(str(datos.get("stat_aumentada", "")))


## MossdeepCity_House1_EventScript_15A82F (lock + faceplayer).
func _on_experto(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	var lider: BasePokemon = CintaEsfuerzo.pokemon_lider(SistemaGuardado.get_equipo())
	if lider == null:
		terminar(false, [npc])
		return
	await mensaje(TEXTO_EXPERTO_INTRO, true, {"{especie}": lider.nombre})
	var sabor: int = sabor_preferido(lider.naturaleza)
	if sabor < 0:
		await mensaje(TEXTO_EXPERTO_IGUAL)  # EventScript_15A855
	else:
		await mensaje(TEXTO_EXPERTO_GUSTA, true, {"{cubo}": tr(CUBOS[sabor])})
	terminar(false, [npc])


## ============================================================================
## CASA 4: el chico de las BASES SECRETAS
## ============================================================================

## GetSecretBaseNearbyMapName: nombre legible de la sección del mapa donde está la base del jugador.
static func lugar_de_la_base(bases: SistemaBasesSecretas) -> String:
	var entrada: Dictionary = DatosBasesSecretas.entrada(bases.id_base())
	return Lugares.nombre_lugar(Lugares.seccion_de_escena(str(entrada.get("mapa", ""))))


## MossdeepCity_House4_EventScript_15AB50 (lock + faceplayer).
func _on_chico_base(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	var bases: SistemaBasesSecretas = SistemaGuardado.get_bases_secretas()
	if bases != null and bases.tiene_base():  # CheckPlayerHasSecretBase
		await mensaje(TEXTO_CHICO_BASE, true, {"{lugar}": lugar_de_la_base(bases)})
	else:
		await mensaje(TEXTO_CHICO_SIN_BASE)
	terminar(false, [npc])


## ============================================================================
## CASA 6: el WINGULL del correo
## ============================================================================

## MossdeepCity_House2_EventScript_15A87B (lock + faceplayer).
func _on_wingull(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	var mirada: Vector2 = admin.jugador.facing_direction  # VAR_FACING
	var reproductor: Variant = grito(int(npc.get("numero_nacional")))  # waitse + playmoncry
	await mensaje(TEXTO_WINGULL, false)
	await esperar_grito(reproductor)  # waitmoncry
	admin.cuadro_dialogo.cerrar()  # closemessage
	SistemaGuardado.set_flag(EventoInterioresArborada.BANDERA_CORREO, true)
	SistemaGuardado.set_flag(EventoInterioresArborada.BANDERA_WINGULL_FUERA, false)
	var pasos: Array[Vector2] = []
	if mirada == U:
		pasos = SALIDA_MIRANDO_ARRIBA
	elif mirada == L:
		pasos = SALIDA_MIRANDO_IZQUIERDA
	for paso in pasos:
		await caminar(npc, paso, VelocidadPaso.RAPIDO)
	if not pasos.is_empty():
		await esperar_fotogramas(FOTOGRAMAS_ESPERA_SALIDA)
	npc.aplicar_bandera_ocultar()  # removeobject 3
	terminar(false, [npc])
