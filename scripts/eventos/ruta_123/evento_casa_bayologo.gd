## evento_casa_bayologo.gd
## CASA del BAYÓLOGO de la RUTA 123 (pokeruby Route123_BerryMastersHouse). Godot = Rubí.
##
## El BAYÓLOGO (objeto 1) es un NpcRegaloDiario de la escena. Aquí va su esposa (objeto 2, OLD_WOMAN_2 en
## (7,4), FACE_DOWN; `lock` + FacePlayer + dotimebasedevents), una vez al día (FLAG_DAILY_RECEIVED_BERRY_FROM_
## BERRYMASTER_WIFE): pide una «buena expresión» en PALABRAS FÁCILES (tipo 13). Cancelar o dejar un hueco vacío
## → «Ah...» y se puede volver a intentar. Una de las cinco frases de la tabla gBerryMasterWifePhrases, la primera
## vez, da su BAYA especial (WIKANO, PLAMA, SAMBIA, RUDION o ANDANO); cualquier otra frase, o una ya premiada, da
## una de las diez primeras BAYAS al azar.
extends EventoInteriorMalvalona
class_name EventoCasaBayologo

const MOTIVO_PAUSA: StringName = &"casa_bayologo"
const REGALO_DIARIO := preload("res://scripts/npc/npc_regalo_diario.gd")

## Contador del día del último regalo (como `<id_regalo>_dia` de NpcRegaloDiario).
const CLAVE_DIA: String = "ruta_123_bayologa_regalo_dia"
## gBerryMasterWifePhrases de la ROM española (0x083DF188), como ids de PALABRAS FÁCILES:
## GRAN COMBATE, DESAFÍO CONCURSO, INCREÍBLE LATIAS, CARISMÁTICO LATIOS y SUPER EMOCIONANTE.
const FRASES: Array[Array] = [
	[0x2009, 0x0628],
	[0x061F, 0x2204],
	[0x1221, 0x0197],
	[0x0416, 0x0198],
	[0x044A, 0x060B],
]
## Por frase: ITEM_SPELON_BERRY, ITEM_PAMTRE_BERRY, ITEM_WATMEL_BERRY, ITEM_DURIN_BERRY e ITEM_BELUE_BERRY.
const BAYAS_ESPECIALES: Array[String] = ["BAYAWIKANO", "BAYAPLAMA", "BAYASAMBIA", "BAYARUDION", "BAYAANDANO"]
## Por frase: FLAG_RECEIVED_SPELON_BERRY … FLAG_RECEIVED_BELUE_BERRY.
const BANDERAS_ESPECIALES: Array[String] = [
	"ruta_123_baya_wikano_recibida",
	"ruta_123_baya_plama_recibida",
	"ruta_123_baya_sambia_recibida",
	"ruta_123_baya_rudion_recibida",
	"ruta_123_baya_andano_recibida",
]
## `random 10` + ITEM_CHERI_BERRY.
const BAYAS_COMUNES: Array[String] = [
	"BAYAZREZA", "BAYAATANIA", "BAYAMELOC", "BAYASAFRE", "BAYAPERASI",
	"BAYAZANAMA", "BAYAARANJA", "BAYACAQUIC", "BAYAZIUELA", "BAYAZIDRA",
]

const TEXTO_INTRO: String = "RUTA123_BAYOLOGA_INTRO"
const TEXTO_EXCEPCIONAL: String = "RUTA123_BAYOLOGA_EXCEPCIONAL"
const TEXTO_BUENA: String = "RUTA123_BAYOLOGA_BUENA"
const TEXTO_NIETOS: String = "RUTA123_BAYOLOGA_NIETOS"
const TEXTO_AH: String = "RUTA123_BAYOLOGA_AH"

@export var bayologa: NodePath

## Día actual; se puede sustituir en tests.
var proveedor_dia: Callable = REGALO_DIARIO.dia_local_actual
## Sustituye la pantalla de PALABRAS FÁCILES (tests): devuelve las palabras o [] si se cancela.
var editor_frase: Callable = Callable()


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(bayologa, _on_bayologa)


## sub_80E810C: índice en FRASES o -1. Compara la grafía, no el id: la misma palabra en otro grupo también vale.
static func indice_frase(palabras: Array[int]) -> int:
	if palabras.size() != 2:
		return -1
	for i in FRASES.size():
		if PalabrasFaciles.texto(palabras[0]) == PalabrasFaciles.texto(FRASES[i][0]) \
				and PalabrasFaciles.texto(palabras[1]) == PalabrasFaciles.texto(FRASES[i][1]):
			return i
	return -1


## Confirmación del tipo 13 (easy_chat_1.c): cancelar o dejar un hueco vacío deja gSpecialVar_Result a 0.
static func frase_completa(palabras: Array[int]) -> bool:
	return palabras.size() == 2 and not palabras.has(PalabrasFaciles.PALABRA_VACIA)


func _regalo_entregado_hoy() -> bool:
	if not SistemaGuardado.datos_vivos.datos_persistentes.contadores.has(CLAVE_DIA):
		return false
	return SistemaGuardado.get_contador(CLAVE_DIA) == int(proveedor_dia.call())


func _escribir_frase() -> Array[int]:
	var palabras: Array[int] = []
	if editor_frase.is_valid():
		palabras.assign(editor_frase.call())
	else:
		palabras = await PantallaPalabrasFaciles.escribir(self, PantallaPalabrasFaciles.Modo.EXPRESION)
	return palabras


## Route123_BerryMastersHouse_EventScript_163A64.
func _on_bayologa(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if _regalo_entregado_hoy():
		await mensaje(TEXTO_NIETOS)
		terminar(false, [npc])
		return
	await mensaje(TEXTO_INTRO)
	var palabras: Array[int] = await _escribir_frase()
	npc.mirar_jugador()
	if not frase_completa(palabras):
		await mensaje(TEXTO_AH, false)
		await mensaje(TEXTO_NIETOS)
		terminar(false, [npc])
		return
	var indice: int = indice_frase(palabras)
	var especial: bool = indice >= 0 and not SistemaGuardado.get_flag(BANDERAS_ESPECIALES[indice])
	await mensaje(TEXTO_EXCEPCIONAL if especial else TEXTO_BUENA, false)
	var baya: String = BAYAS_ESPECIALES[indice] if especial else BAYAS_COMUNES[randi() % BAYAS_COMUNES.size()]
	if not await dar_objeto(npc, baya):
		await mensaje_mochila_llena()
		terminar(false, [npc])
		return
	if especial:
		SistemaGuardado.set_flag(BANDERAS_ESPECIALES[indice], true)
	SistemaGuardado.set_contador(CLAVE_DIA, int(proveedor_dia.call()))
	await mensaje(TEXTO_NIETOS)
	terminar(false, [npc])
