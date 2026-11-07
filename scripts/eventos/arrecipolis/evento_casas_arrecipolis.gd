## evento_casas_arrecipolis.gd
## Guiones de las casas de ARRECÍPOLIS que no son un msgbox, un SÍ/NO o un regalo de objeto
## (esos van con npc_dialogo_condicional / npc_regalo_objeto / npc_pokemon en la escena). Cada
## escena asigna solo lo que tiene.
##
## - CASA 6 (SootopolisCity_House6, EventScript_Woman): la primera vez pregunta si quieres el
##   MUÑECO WAILMER. NO → «¿seguro que no lo quieres?» y nada más (vuelve a preguntar); SÍ →
##   «¡Cuídalo mucho!» y givedecoration DECOR_WAILMER_DOLL: si no cabe, «no queda sitio» y «te lo
##   guardo» sin bandera; si cabe, FLAG_RECEIVED_WAILMER_DOLL. Después: «¡Me encantan los MUÑECOS!».
## - CASA 8 (SootopolisCity_MonSizeRecordHouse): los dos hermanos piden ver un BARBOACH o un
##   SHROOMISH grande (SelectMonForNPCTrade + Compare*Size, RecordTamano): cancelar, «no es un X»,
##   «he visto uno más grande» o, con récord nuevo, el ÉLIXIR (si la mochila está llena, su propio
##   aviso; el récord ya queda guardado, como en Rubí). Los dos carteles muestran el récord
##   (Get*SizeRecordInfo): nombre (MARCO al principio) y tamaño.
extends EventoInteriorMalvalona
class_name EventoCasasArrecipolis

signal _equipo_cerrado

const MOTIVO_PAUSA: StringName = &"casas_arrecipolis"
const ESCENA_EQUIPO: String = "res://UI/equipo/pantalla-equipo.tscn"

## DECOR_WAILMER_DOLL.
const DECORACION_MUNECO_WAILMER: int = 117
## FLAG_RECEIVED_WAILMER_DOLL.
const BANDERA_MUNECO_WAILMER: String = "arrecipolis_muneco_wailmer_recibido"
const OBJETO_PREMIO: String = "ELIXIR"

const T6 := "ARRECIPOLIS_CASA6_"
const TEXTO_MUNECO_PREGUNTA: String = T6 + "MUJER_PREGUNTA"
const TEXTO_MUNECO_CUIDALO: String = T6 + "MUJER_CUIDALO"
const TEXTO_MUNECO_NO: String = T6 + "MUJER_NO"
const TEXTO_MUNECO_TRAS: String = T6 + "MUJER_TRAS"
const TEXTO_MUNECO_GUARDO: String = T6 + "MUJER_GUARDO"
## Los de la CASA TRETA: «no queda sitio para X», «obtuvo X», «enviada al PC».
const TEXTO_DECOR_SIN_SITIO: String = "CASA_TRETA_DECOR_SIN_SITIO"
const TEXTO_DECOR_OBTENIDA: String = "CASA_TRETA_DECOR_OBTENIDA"
const TEXTO_DECOR_ENVIADA_PC: String = "CASA_TRETA_DECOR_ENVIADA_PC"

## Claves de la CASA 8 por especie: ARRECIPOLIS_CASA8_<ESPECIE>_<sufijo>.
const T8 := "ARRECIPOLIS_CASA8_"
const SUFIJO_PIDE := "_PIDE"
const SUFIJO_CANCELA := "_CANCELA"
const SUFIJO_OTRA := "_OTRA_ESPECIE"
const SUFIJO_PEQUENO := "_MAS_PEQUENO"
const SUFIJO_RECORD := "_RECORD"
const SUFIJO_MOCHILA := "_MOCHILA_LLENA"
const SUFIJO_CARTEL := "_CARTEL"

@export var mujer_muneco: NodePath
@export var hermano_barboach: NodePath
@export var hermano_shroomish: NodePath
@export var cartel_barboach: NodePath
@export var cartel_shroomish: NodePath

## Sustituye a la pantalla del equipo (tests): devuelve el índice elegido o -1.
var selector_equipo: Callable = Callable()


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(mujer_muneco, _on_mujer_muneco)
	escuchar(hermano_barboach, _on_hermano.bind(RecordTamano.BARBOACH))
	escuchar(hermano_shroomish, _on_hermano.bind(RecordTamano.SHROOMISH))
	for par: Array in [[cartel_barboach, RecordTamano.BARBOACH], [cartel_shroomish, RecordTamano.SHROOMISH]]:
		var cartel := get_node_or_null(par[0] as NodePath) as CartelEvento
		if cartel != null:
			cartel.accionado.connect(_on_cartel.bind(str(par[1])))


## ============================================================================
## CASA 6: el MUÑECO WAILMER
## ============================================================================

## SootopolisCity_House6_EventScript_Woman (lock + faceplayer).
func _on_mujer_muneco(npc: Node2D) -> void:
	if not empezar_con(npc):
		return
	if SistemaGuardado.get_flag(BANDERA_MUNECO_WAILMER):
		await mensaje(TEXTO_MUNECO_TRAS)  # ReceivedWailmerDoll
		terminar(false, [npc])
		return
	if not await preguntar_si_no(TEXTO_MUNECO_PREGUNTA):
		await mensaje(TEXTO_MUNECO_NO)  # DeclineWailmerDoll
		terminar(false, [npc])
		return
	await mensaje(TEXTO_MUNECO_CUIDALO)
	var nombre := tr("BASES_DECOR_%03d_NOMBRE" % DECORACION_MUNECO_WAILMER)
	if SistemaGuardado.get_bases_secretas().agregar_decoracion(DECORACION_MUNECO_WAILMER) < 0:
		await mensaje(TEXTO_DECOR_SIN_SITIO, true, {"{decoracion}": nombre})  # NoRoomForWailmerDoll
		await mensaje(TEXTO_MUNECO_GUARDO)
		terminar(false, [npc])
		return
	await mensaje_con_fanfarria(TEXTO_DECOR_OBTENIDA, FANFARRIA_OBJETO, {"{decoracion}": nombre})
	await mensaje(TEXTO_DECOR_ENVIADA_PC, true, {"{decoracion}": nombre})
	SistemaGuardado.set_flag(BANDERA_MUNECO_WAILMER, true)
	terminar(false, [npc])


## ============================================================================
## CASA 8: los récords de tamaño
## ============================================================================

## SootopolisCity_MonSizeRecordHouse_EventScript_BarboachBrother / ShroomishBrother.
func _on_hermano(npc: Node2D, especie: String) -> void:
	if not empezar_con(npc):
		return
	var clave := T8 + especie
	await mensaje(clave + SUFIJO_PIDE, false)
	var indice: int = await _elegir_del_equipo()
	var equipo: Array = SistemaGuardado.get_equipo()
	var pokemon: BasePokemon = equipo[indice] if indice >= 0 and indice < equipo.size() else null
	var comparacion := RecordTamano.comparar(especie, pokemon)
	var tamano := {"{tamano}": RecordTamano.formatear_local(int(comparacion["tamano"]))}
	match int(comparacion["resultado"]):
		RecordTamano.Resultado.CANCELADO:
			await mensaje(clave + SUFIJO_CANCELA)
		RecordTamano.Resultado.OTRA_ESPECIE:
			await mensaje(clave + SUFIJO_OTRA)
		RecordTamano.Resultado.MAS_PEQUENO:
			await mensaje(clave + SUFIJO_PEQUENO, true, tamano)
		RecordTamano.Resultado.NUEVO_RECORD:
			await mensaje(clave + SUFIJO_RECORD, false, tamano)
			if not await dar_objeto(npc, OBJETO_PREMIO):
				await mensaje(clave + SUFIJO_MOCHILA)
	terminar(false, [npc])


## SootopolisCity_MonSizeRecordHouse_EventScript_*SizeRecord (lockall).
func _on_cartel(_cartel: CartelEvento, especie: String) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	var info := RecordTamano.info_record(especie)
	await mensaje(T8 + especie + SUFIJO_CARTEL, true,
			{"{nombre}": info["nombre"], "{tamano}": RecordTamano.formatear_local(int(info["tamano"]))})
	terminar()


## SelectMonForNPCTrade: equipo en modo ELEGIR con fundidos (patrón de intercambio_npc.gd).
## Devuelve el índice elegido o -1 si se cancela.
func _elegir_del_equipo() -> int:
	if selector_equipo.is_valid():
		return int(selector_equipo.call())
	var capa := get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	if capa == null:
		return -1
	admin.cuadro_dialogo.cerrar()
	await Singleton.transicion("oscurecer")
	var equipo := EquipoPokemon.new()
	for poke: BasePokemon in SistemaGuardado.get_equipo():
		equipo.agregar_pokemon(poke)
	var pantalla := (load(ESCENA_EQUIPO) as PackedScene).instantiate() as PantallaEquipoControlador
	capa.add_child(pantalla)
	var eleccion := {"indice": -1, "lista": false}
	pantalla.pokemon_elegido.connect(func(i: int) -> void:
		eleccion["indice"] = i
		eleccion["lista"] = true
		_equipo_cerrado.emit()
	, CONNECT_ONE_SHOT)
	pantalla.seleccion_cancelada.connect(func() -> void:
		eleccion["lista"] = true
		_equipo_cerrado.emit()
	, CONNECT_ONE_SHOT)
	pantalla.mostrar_equipo_modo(Singleton.ModoPEquipo.ELEGIR, equipo)
	await Singleton.transicion("aclarar")
	if not bool(eleccion["lista"]):
		await _equipo_cerrado
	pantalla.activo = false
	await Singleton.transicion("oscurecer")
	pantalla.ocultar_pantalla_equipo()
	pantalla.queue_free()
	await Singleton.transicion("aclarar")
	return int(eleccion["indice"])
