## evento_maquina_licuabayas.gd
## LICUABAYAS de los vestíbulos de CONCURSOS (pokeruby data/scripts/pokeblocks.inc).
##
## Con rivales (bg_event (12,5) de Verdegal, Pardal y Portual; (18,9) de Calagua):
## `..._EventScript_BerryBlender2` y compañía. El viejo (VAR_0x8008) mira a la máquina
## (walk_in_place_fastest_right), los demás NPC de la mesa vuelven a su dirección
## (Common_Movement_FaceOriginalDirection) y luego `..._EventScript_1B7681`:
##   «¿quieres hacer algunos POKéCUBOS con este viejales?» SÍ/NO; sin TUBO (checkitem
##   ITEM_POKEBLOCK_CASE) o sin BAYAS (PlayerHasBerries) su mensaje; sin BAYAS además
##   el regalo diario de BAYA MELOC del viejo (FLAG_DAILY_RECEIVED_BERRY_FALLARBOR,
##   compartido con su conversación, que salta la comprobación del TUBO lleno); con
##   BAYAS «¡Maravilloso!» y, con el TUBO lleno (GetFirstFreePokeblockSlot), su mensaje;
##   «¿Sabes cómo hacer POKéCUBOS?» (NO: la explicación), «¡A por la LICUABAYAS!»,
##   fadescreen y DoBerryBlending con VAR_0x8004 = `num_rivales`.
##
## Por cable (`por_cable`, bg_event (10,3) o (18,5), `..._EventScript_1B783B`): las
## mismas comprobaciones con sus textos. No hay cable Game Link, así que en lugar de
## «Debes guardar la partida...» y «Buscando a tus amigos...» se ofrece un modo sin
## conexión (no está en Rubí): SÍ/NO, cuántos rivales NPC (1-3), «¿Sabes cómo hacer
## POKéCUBOS?» y la misma partida que la máquina con rivales.
extends EventoGuionizado
class_name EventoMaquinaLicuabayas

const MOTIVO_PAUSA: StringName = &"maquina_licuabayas"
const ESCENA_PARTIDA: PackedScene = preload("res://escenas/licuadora/partida_licuadora.tscn")
## ITEM_POKEBLOCK_CASE.
const OBJETO_TUBO: String = "CAJAPOKECUBOS"
const BOLSILLO_TUBO: int = 4

const TEXTO_PREGUNTA: String = "LICUADORA_MAQUINA_PREGUNTA"
const TEXTO_SI: String = "LICUADORA_MAQUINA_SI"
const TEXTO_NO: String = "LICUADORA_MAQUINA_NO"
const TEXTO_SABES: String = "LICUADORA_MAQUINA_SABES"
const TEXTO_EMPEZAR: String = "LICUADORA_MAQUINA_EMPEZAR"
const TEXTO_EXPLICACION: String = "LICUADORA_MAQUINA_EXPLICACION"
const TEXTO_SIN_BAYAS: String = "LICUADORA_MAQUINA_SIN_BAYAS"
const TEXTO_REGALO: String = "LICUADORA_MAQUINA_REGALO"
const TEXTO_YA_REGALO: String = "LICUADORA_MAQUINA_YA_REGALO"
const TEXTO_TUBO_LLENO: String = "LICUADORA_MAQUINA_TUBO_LLENO"
const TEXTO_SIN_TUBO: String = "LICUADORA_MAQUINA_SIN_TUBO"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
const TEXTO_CABLE_SIN_CONEXION: String = "LICUADORA_CABLE_SIN_CONEXION"
const TEXTO_CABLE_RIVALES: String = "LICUADORA_CABLE_RIVALES"
## Opciones del menú de rivales del modo sin conexión; la última cancela.
const OPCIONES_CABLE_RIVALES: Array[String] = [
	"LICUADORA_CABLE_OPCION_1", "LICUADORA_CABLE_OPCION_2", "LICUADORA_CABLE_OPCION_3",
	"LICUADORA_CABLE_OPCION_SALIR",
]
const TEXTO_CABLE_SIN_BAYAS: String = "LICUADORA_CABLE_SIN_BAYAS"
const TEXTO_CABLE_TUBO_LLENO: String = "LICUADORA_CABLE_TUBO_LLENO"
const TEXTO_CABLE_SIN_TUBO: String = "LICUADORA_CABLE_SIN_TUBO"

## El cartel (bg_event) de la máquina.
@export var cartel: NodePath
## VAR_0x8009: rivales NPC (1-3).
@export_range(1, 3) var num_rivales: int = 1
## Máquina para jugar por cable con amigos (sin rivales NPC).
@export var por_cable: bool = false
## VAR_0x8008: el viejo de los POKéCUBOS (npc_viejo_licuabayas.gd), que da la BAYA diaria.
@export var viejo: NodePath
## NPC de la mesa que vuelven a su dirección original (Common_Movement_FaceOriginalDirection).
@export var npcs_mesa: Array[NodePath] = []

## Sustituye al AdministradorMapa de la raíz (tests).
var administrador: Node = null
## Tests: se llama con la partida ya creada y configurada, antes de ejecutarla.
var al_crear_partida: Callable = Callable()
## Tests: sin fundidos.
var sin_transiciones: bool = false
## Última partida jugada (tests).
var ultima_partida: ControladorLicuadora = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var maquina := get_node_or_null(cartel)
	if maquina != null and maquina.has_signal("accionado"):
		maquina.accionado.connect(_on_accionado)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _on_accionado(_cartel: Node) -> void:
	if not comenzar(_administrador()):
		return
	if por_cable:
		await _guion_cable()
	else:
		await _guion_rivales()
	terminar(false)


## checkitem ITEM_POKEBLOCK_CASE, 1.
static func tiene_tubo() -> bool:
	return SistemaGuardado.get_cantidad_objeto(OBJETO_TUBO, BOLSILLO_TUBO) > 0


## GetFirstFreePokeblockSlot == -1.
static func tubo_lleno() -> bool:
	return SistemaGuardado.obtener_estuche_pokecubos().esta_lleno()


## FallarborTown_ContestLobby_EventScript_1B7681 y siguientes.
func _guion_rivales() -> void:
	var npc_viejo: Node2D = get_node_or_null(viejo) as Node2D
	if npc_viejo != null:
		mirar(npc_viejo, Vector2.RIGHT)
	for ruta in npcs_mesa:
		var npc: Node = get_node_or_null(ruta)
		if npc != null and npc.has_method("direccion_inicial"):
			npc.direccion_inicial()
	if not await preguntar_si_no(TEXTO_PREGUNTA):
		await mensaje(TEXTO_NO)
		return
	if not tiene_tubo():
		await mensaje(TEXTO_SIN_TUBO)
		return
	if not ControladorLicuadora.jugador_tiene_bayas():
		await mensaje(TEXTO_SIN_BAYAS)
		if npc_viejo == null or npc_viejo.call("regalo_entregado_hoy"):
			await mensaje(TEXTO_YA_REGALO)
			return
		await mensaje(TEXTO_REGALO)
		if not npc_viejo.call("entregar_regalo"):
			await mensaje(TEXTO_MOCHILA_LLENA)
			return
		await npc_viejo.mostrar_objeto_recibido(str(npc_viejo.get("objeto_entregado")))
	else:
		await mensaje(TEXTO_SI)
		if tubo_lleno():
			await mensaje(TEXTO_TUBO_LLENO)
			return
	if not await preguntar_si_no(TEXTO_SABES):
		await mensaje(TEXTO_EXPLICACION)
	await mensaje(TEXTO_EMPEZAR)
	await jugar_partida(num_rivales)


## copyvar VAR_0x8004, VAR_0x8009 + fadescreen FADE_TO_BLACK + special DoBerryBlending
## + waitstate: la partida en la capa Menu y, al acabar, de vuelta al mapa.
func jugar_partida(rivales: int) -> void:
	admin.cuadro_dialogo.cerrar()
	if not sin_transiciones:
		await oscurecer_pantalla()
	var partida := ESCENA_PARTIDA.instantiate() as ControladorLicuadora
	partida.num_rivales = rivales
	partida.administrador = admin
	partida.cuadro_dialogo = admin.cuadro_dialogo
	ultima_partida = partida
	var capa: Node = admin.get_node_or_null("Menu")
	(capa if capa != null else admin).add_child(partida)
	if al_crear_partida.is_valid():
		al_crear_partida.call(partida)
	if not sin_transiciones:
		await aclarar_pantalla()
	await partida.ejecutar()
	admin.cuadro_dialogo.cerrar()
	if not sin_transiciones:
		await oscurecer_pantalla()
	partida.get_parent().remove_child(partida)
	partida.queue_free()
	restaurar_musica_mapa()
	if not sin_transiciones:
		await aclarar_pantalla()


## FallarborTown_ContestLobby_EventScript_1B783B (máquina por cable).
func _guion_cable() -> void:
	if not ControladorLicuadora.jugador_tiene_bayas():
		await mensaje(TEXTO_CABLE_SIN_BAYAS)
		return
	if not tiene_tubo():
		await mensaje(TEXTO_CABLE_SIN_TUBO)
		return
	if tubo_lleno():
		await mensaje(TEXTO_CABLE_TUBO_LLENO)
		return
	if not await preguntar_si_no(TEXTO_CABLE_SIN_CONEXION):
		return
	var opciones := PackedStringArray()
	for clave in OPCIONES_CABLE_RIVALES:
		opciones.append(tr(clave))
	var eleccion := await elegir_opcion(TEXTO_CABLE_RIVALES, opciones)
	if eleccion >= OPCIONES_CABLE_RIVALES.size() - 1:
		return
	if not await preguntar_si_no(TEXTO_SABES):
		await mensaje(TEXTO_EXPLICACION)
	await jugar_partida(eleccion + 1)


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
