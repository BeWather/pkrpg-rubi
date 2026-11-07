## rotacion_gabi_teo.gd
## GABI y TEO, la pareja de periodistas de «En busca de entrenadores» (pokeruby
## data/scripts/gabby_and_ty.inc, src/tv.c). Van rotando entre la RUTA 111, la
## RUTA 118 y la RUTA 120: en cada momento solo una de sus ocho apariciones está
## visible en todo HOENN y, tras ganarles, aparecen en la siguiente ruta al entrar.
##
## Un nodo de este tipo por mapa (Route111/118/120_EventScript_1AE313 del
## MAP_SCRIPT_ON_TRANSITION): al activarse el mapa hace `cleartrainerflag
## TRAINER_GABBY_AND_TY_6` y fija las banderas FLAG_HIDE_GABBY_AND_TY_* según
## GabbyAndTyGetBattleNum. El contador gabbyAndTyData.battleNum vive en
## SistemaGuardado (contador CONTADOR_COMBATES) y sube al ganar a la pareja, en
## GabbyAndTyBeforeInterview (DatosGabiTeo.antes_de_entrevista, que llama
## EntrevistaGabiTeo); al perder no cambia.
extends Node
class_name RotacionGabiTeo

## gabbyAndTyData.battleNum.
const CONTADOR_COMBATES: String = "gabi_teo_num_combate"
## GabbyAndTyBeforeInterview deja de sumar al llegar a 0xff.
const TOPE_COMBATES: int = 0xff
## TRAINER_GABBY_AND_TY_6: el único repetible (cleartrainerflag al entrar).
const NPC_ID_REPETIBLE: String = "gabi_teo_6"

## Las ocho apariciones (object_events con flag FLAG_HIDE_GABBY_AND_TY_*).
const BANDERAS: Array[String] = [
	"FLAG_HIDE_GABBY_AND_TY_ROUTE111_1",
	"FLAG_HIDE_GABBY_AND_TY_ROUTE118_1",
	"FLAG_HIDE_GABBY_AND_TY_ROUTE120_1",
	"FLAG_HIDE_GABBY_AND_TY_ROUTE111_2",
	"FLAG_HIDE_GABBY_AND_TY_ROUTE118_2",
	"FLAG_HIDE_GABBY_AND_TY_ROUTE120_2",
	"FLAG_HIDE_GABBY_AND_TY_ROUTE111_3",
	"FLAG_HIDE_GABBY_AND_TY_ROUTE118_3",
]
## Route111_EventScript_1AE313: resultado de GabbyAndTyGetBattleNum (0..8) ->
## índice en BANDERAS de la aparición que queda visible. El caso 8 vuelve a la
## RUTA 120 (ROUTE120_2), no a una aparición nueva.
const APARICION_POR_COMBATE: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 5]

## Los NPC de Gabi y Teo de este mapa (npc_entrenador).
@export var miembros: Array[NodePath] = []

var _miembros: Array[Node] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for ruta: NodePath in miembros:
		var npc := get_node_or_null(ruta)
		if npc == null:
			push_warning("[GABI_TEO] Miembro no encontrado: %s" % ruta)
			continue
		_miembros.append(npc)
	var mapa := _obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar()


func _on_mapa_activado(_por_warp: bool) -> void:
	preparar()


## MAP_SCRIPT_ON_TRANSITION: actualiza las banderas y los NPC de este mapa. Corre
## después de que los NPC reevalúen su bandera_ocultar, así que la vuelve a aplicar.
func preparar() -> void:
	aplicar_rotacion()
	for npc: Node in _miembros:
		if npc.has_method("rearmar_combate_si_bandera_borrada"):
			npc.rearmar_combate_si_bandera_borrada()
		if npc.has_method("aplicar_bandera_ocultar"):
			npc.aplicar_bandera_ocultar()


## GabbyAndTyGetBattleNum.
static func numero_combate(combates: int) -> int:
	if combates >= 6:
		return combates % 3 + 6
	return combates


## Bandera FLAG_HIDE_* de la aparición visible con `combates` combates ganados.
static func bandera_visible(combates: int) -> String:
	return BANDERAS[APARICION_POR_COMBATE[numero_combate(combates)]]


static func combates_ganados() -> int:
	return SistemaGuardado.get_contador(CONTADOR_COMBATES)


## Route111_EventScript_1AE313. Fija las ocho banderas a la vez: la ROM solo
## muestra la nueva aparición y oculta la anterior, lo que desde new_game.inc
## (todas ocultas menos ROUTE111_1) da siempre este mismo estado.
static func aplicar_rotacion() -> void:
	SistemaGuardado.set_flag(NPC_ID_REPETIBLE + "_combate", false)
	var visible_ahora := bandera_visible(combates_ganados())
	for bandera: String in BANDERAS:
		SistemaGuardado.set_flag(bandera, bandera != visible_ahora)


## GabbyAndTyBeforeInterview: battleNum++ (con tope 0xff).
static func registrar_combate() -> void:
	if combates_ganados() < TOPE_COMBATES:
		SistemaGuardado.incrementar_contador(CONTADOR_COMBATES)


func _obtener_mapa() -> MapaConfiguracion:
	var nodo := get_parent()
	while nodo != null and not nodo is MapaConfiguracion:
		nodo = nodo.get_parent()
	return nodo as MapaConfiguracion
