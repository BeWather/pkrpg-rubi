## entrevista_gabi_teo.gd
## La entrevista de GABI y TEO tras ganarles (pokeruby data/scripts/gabby_and_ty.inc:
## Route111_EventScript_1AE5A2 en el primer combate, 1AE60F en los demás, y
## 1AE6F3 / 1AE72D / 1AE73A). Es el guion de victoria de trainerbattle_double: se
## engancha a los NPC de la pareja como `continuacion_victoria` y corre antes de
## devolver el control. Hablarles después no pasa por aquí (solo su texto post).
##
##   special GabbyAndTyBeforeInterview      → DatosGabiTeo.antes_de_entrevista
##   (sin último movimiento: FLAG_TEMP_1)
##   los dos se giran según VAR_FACING (walk_in_place_*)
##   FLAG_TEMP_1 → «¡Te seguiremos de cerca!» y fin
##   1er combate: «¡Asombroso!…» (SÍ/NO)
##   si no: cita anterior (GabbyAndTyGetLastQuote, que la borra) + curiosidad
##          (GabbyAndTyGetLastBattleTrivia), o «Guau…» sin cita (SÍ/NO)
##   NO → «Oh…»; SÍ → «¿Te apetece?…», PALABRAS FÁCILES de una palabra
##   (ShowEasyChatScreen con VAR_0x8004 = 10, que antes pone quote = 0xFFFF);
##   cancelar → «Oh…»; aceptar → «Mmmm… ¡Sí!…» + GabbyAndTyAfterInterview.
##   Al acabar, FLAG_TEMP_1.
extends EventoGuionizado
class_name EntrevistaGabiTeo

const MOTIVO_PAUSA: StringName = &"gabi_teo_entrevista"
## FLAG_TEMP_1 del guion (se borra al recargar el mapa).
const BANDERA_TEMPORAL: String = "gabi_teo_entrevista_hecha"
## TRAINER_GABBY_AND_TY_1: su guion es el de la primera vez (1AE5A2).
const ENTRENADOR_PRIMER_COMBATE: int = 51
const ESCENA_PALABRAS_FACILES: String = "res://UI/palabras_faciles/pantalla_palabras_faciles.tscn"

const TEXTO_POST: String = "GABI_TEO_GABI_POST"
const TEXTO_PRIMERA: String = "GABI_TEO_ENTREVISTA_PRIMERA"
const TEXTO_CITA: String = "GABI_TEO_ENTREVISTA_CITA"
const TEXTO_SIN_CITA: String = "GABI_TEO_ENTREVISTA_SIN_CITA"
const TEXTO_ACEPTA: String = "GABI_TEO_ENTREVISTA_ACEPTA"
const TEXTO_GRACIAS: String = "GABI_TEO_ENTREVISTA_GRACIAS"
const TEXTO_NO: String = "GABI_TEO_ENTREVISTA_NO"
## GabbyAndTyGetLastBattleTrivia → texto (1AE6AD..1AE6E5).
const TEXTOS_CURIOSIDAD: Dictionary = {
	DatosGabiTeo.Curiosidad.NINGUNA: "GABI_TEO_ENTREVISTA_OTRA_VEZ",
	DatosGabiTeo.Curiosidad.SIN_DANO: "GABI_TEO_ENTREVISTA_SIN_DANO",
	DatosGabiTeo.Curiosidad.BALLS: "GABI_TEO_ENTREVISTA_BALLS",
	DatosGabiTeo.Curiosidad.OBJETOS: "GABI_TEO_ENTREVISTA_OBJETOS",
	DatosGabiTeo.Curiosidad.DEBILITADOS: "GABI_TEO_ENTREVISTA_DEBILITADOS",
}

## Parejas de este mapa: gabis[i] y teos[i] son la misma aparición.
@export var gabis: Array[NodePath] = []
@export var teos: Array[NodePath] = []

## Sustituye a la pantalla de PALABRAS FÁCILES (tests): recibe nada y devuelve el
## id de la palabra aceptada o DatosGabiTeo.SIN_CITA si se cancela.
var editor_cita: Callable = Callable()

var _gabis: Array[Node2D] = []
var _teos: Array[Node2D] = []


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for i in mini(gabis.size(), teos.size()):
		var gabi := get_node_or_null(gabis[i]) as Node2D
		var teo := get_node_or_null(teos[i]) as Node2D
		if gabi == null or teo == null:
			push_warning("[GABI_TEO] Pareja %d incompleta" % i)
			continue
		_gabis.append(gabi)
		_teos.append(teo)
		for npc: Node2D in [gabi, teo]:
			npc.set("continuacion_victoria", entrevistar)


## Guion de victoria de la pareja a la que pertenece `npc` (el que inició el combate).
func entrevistar(npc: Node2D) -> void:
	var indice := maxi(_gabis.find(npc), _teos.find(npc))
	if indice < 0:
		return
	var gabi: Node2D = _gabis[indice]
	var teo: Node2D = _teos[indice]
	# BeforeInterview cuenta la victoria aunque el guion no pudiera mostrarse.
	if DatosGabiTeo.antes_de_entrevista(ResultadosCombate.actual):
		SistemaGuardado.set_flag_temporal(BANDERA_TEMPORAL, true)
	if not comenzar(npc.get("nodo_administrador")):
		return
	await _girar_hacia_jugador(gabi, teo)
	if SistemaGuardado.get_flag_temporal(BANDERA_TEMPORAL):
		await mensaje(TEXTO_POST)
		terminar(false, [gabi, teo])
		return
	if await _preguntar_entrevista(int(npc.get("entrenador_id"))):
		await mensaje(TEXTO_ACEPTA)
		var palabra := await _escribir_cita()
		if npc.has_method("mirar_jugador"):
			npc.mirar_jugador()  # lock + faceplayer
		if palabra != DatosGabiTeo.SIN_CITA:
			DatosGabiTeo.set_cita(palabra)
			await mensaje(TEXTO_GRACIAS)
			var mapa := obtener_mapa()
			DatosGabiTeo.despues_de_entrevista(mapa.seccion if mapa != null else "")
		else:
			await mensaje(TEXTO_NO)
	else:
		await mensaje(TEXTO_NO)
	SistemaGuardado.set_flag_temporal(BANDERA_TEMPORAL, true)
	terminar(false, [gabi, teo])


## 1AE5A2 (primer combate) o 1AE60F (cita anterior y curiosidad, o sin cita).
func _preguntar_entrevista(entrenador_id: int) -> bool:
	if entrenador_id == ENTRENADOR_PRIMER_COMBATE:
		return await preguntar_si_no(TEXTO_PRIMERA)
	var cita := DatosGabiTeo.tomar_ultima_cita()
	if cita == DatosGabiTeo.SIN_CITA:
		return await preguntar_si_no(TEXTO_SIN_CITA)
	await mensaje(TEXTO_CITA, true, {"{palabra}": PalabrasFaciles.texto(cita)})
	return await preguntar_si_no(TEXTOS_CURIOSIDAD[DatosGabiTeo.ultima_curiosidad()])


## Route111_EventScript_1AE5E0 / 5EB / 5FD según VAR_FACING (hacia dónde mira el
## jugador): arriba → GABI mira abajo; abajo → los dos miran arriba; derecha → los
## dos miran a la izquierda; izquierda → nada.
func _girar_hacia_jugador(gabi: Node2D, teo: Node2D) -> void:
	var jugador: Node = admin.get("jugador")
	if jugador == null:
		return
	match Vector2(jugador.get("facing_direction")):
		Vector2.UP:
			await trotar_en_sitio(gabi, Vector2.DOWN, 1, 16)
		Vector2.DOWN:
			mirar(teo, Vector2.UP)
			await trotar_en_sitio(gabi, Vector2.UP, 1, 16)
		Vector2.RIGHT:
			mirar(teo, Vector2.LEFT)
			await trotar_en_sitio(gabi, Vector2.LEFT, 1, 16)


## Common_EventScript_ShowEasyChatScreen con VAR_0x8004 = 10: la cita queda a
## 0xFFFF al abrir; devuelve la palabra aceptada o SIN_CITA.
func _escribir_cita() -> int:
	DatosGabiTeo.set_cita(DatosGabiTeo.SIN_CITA)
	if editor_cita.is_valid():
		return int(await editor_cita.call())
	var capa: Node = get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	if capa == null:
		return DatosGabiTeo.SIN_CITA
	admin.cuadro_dialogo.cerrar()
	await Singleton.transicion("oscurecer")
	var pantalla := (load(ESCENA_PALABRAS_FACILES) as PackedScene).instantiate() as PantallaPalabrasFaciles
	pantalla.z_index = 6
	capa.add_child(pantalla)
	var vacia: Array[int] = []
	pantalla.abrir(PantallaPalabrasFaciles.Modo.ENTREVISTA, vacia, 1)
	var resultado: Array = await pantalla.terminada
	pantalla.queue_free()
	await Singleton.transicion("aclarar")
	var ids: Array = resultado[1]
	if not bool(resultado[0]) or ids.is_empty():
		return DatosGabiTeo.SIN_CITA
	return int(ids[0])
