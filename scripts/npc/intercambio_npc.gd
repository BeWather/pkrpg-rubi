## intercambio_npc.gd
## Intercambio con un NPC de Rubí («in-game trade»), dirigido por datos: el NPC se indica con
## `npc` (un npc_evento) y la oferta con `id_intercambio`, una clave de
## `BaseDatos/intercambios_npc.json` (`DatosIntercambio`, la tabla `gIngameTrades` de pokeruby).
## Se cuelga en `Eventos` de la escena, como los demás eventos de mapa.
##
## Guion (pokeruby `FortreeCity_House1_EventScript_Trader`, igual en RustboroCity_House1 y
## PacifidlogTown_House3): lock + faceplayer; con la bandera del intercambio puesta, solo dice
## el texto de «ya intercambiado»; si no, oferta SÍ/NO (NO: «si cambias de opinión…»);
## `SelectMonForNPCTrade` (el equipo en modo ELEGIR; cancelar: «si cambias de opinión…»);
## `GetTradeSpecies` ≠ especie pedida (un HUEVO cuenta como ninguna): «¡Ese POKéMON no es un
## X!»; si coincide, `CreateInGameTradePokemon` + `DoInGameTradeScene` y el mensaje de
## agradecimiento, y se activa la bandera.
##
## El trueque (`sub_804BA94` / `sub_804BA18`): el Pokémon recibido ocupa la MISMA ranura del
## equipo (el del jugador se va con su objeto), con 70 de amistad, y su especie queda vista y
## atrapada en la POKéDEX. Después se mira la evolución por intercambio (EVO_TRADE y
## EVO_TRADE_ITEM de `EvolucionPokemon`, modo INTERCAMBIO) con la escena de evolución, no
## cancelable. El recibido tiene como EO al NPC, así que gana la EXP extra de los intercambiados
## (`battle_result_controller._pokemon_tiene_bonus_por_intercambio`).
##
## La escena del trueque es `EscenaIntercambio` (versión sencilla, no la del cable).
extends EventoGuionizado
class_name IntercambioNpc

const MOTIVO_PAUSA: StringName = &"intercambio_npc"
const ESCENA_EQUIPO: String = "res://UI/equipo/pantalla-equipo.tscn"

## Resultados de `ofrecer` (para quien quiera reaccionar y para las pruebas).
const COMPLETADO: StringName = &"completado"
const RECHAZADO: StringName = &"rechazado"
const NO_ES: StringName = &"no_es"
const HECHO: StringName = &"hecho"
const SIN_DATOS: StringName = &"sin_datos"

## Quien habla: el NPC (un npc_evento) con el que se intercambia.
@export var npc: NodePath
## Clave de `intercambios_npc.json` ("ARBORADA"...).
@export var id_intercambio: String = ""

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## Si es válido sustituye a la pantalla de equipo: devuelve el índice elegido o -1 (tests).
var selector_equipo: Callable = Callable()
## false omite la escena del trueque y sus fundidos (tests).
var con_escena: bool = true

## Se emite tras el trueque, con el Pokémon recibido ya en el equipo (y evolucionado, si procede).
signal intercambio_realizado(recibido: BasePokemon)
signal _equipo_cerrado


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var hablante := get_node_or_null(npc)
	if hablante != null and hablante.has_signal("hablado"):
		hablante.hablado.connect(_on_hablado)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## lock + faceplayer al hablarle al NPC. false si ya hay un guion en curso.
func _on_hablado(hablante: Node2D) -> void:
	var administrador_npc: Node = hablante.nodo_administrador if hablante.nodo_administrador != null \
			else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and hablante.jugador and hablante.jugador.has_method("esperar_dialogo"):
			hablante.jugador.esperar_dialogo(false)
		return
	hablante.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	hablante.mirar_jugador()
	await ofrecer()
	terminar(false, [hablante])


## Todo el guion del Trader. Devuelve COMPLETADO, RECHAZADO, NO_ES, HECHO o SIN_DATOS.
func ofrecer() -> StringName:
	var datos := DatosIntercambio.obtener(id_intercambio)
	if datos.is_empty():
		push_warning("[IntercambioNpc] Intercambio '%s' no encontrado" % id_intercambio)
		return SIN_DATOS
	var textos: Dictionary = datos.get("textos", {})
	var bandera := str(datos.get("bandera", ""))
	if SistemaGuardado.get_flag(bandera):
		await mensaje(str(textos["completado"]))  # TradeCompleted
		return COMPLETADO
	var reemplazos := DatosIntercambio.reemplazos_textos(datos)
	if not await preguntar_si_no(str(textos["oferta"]), reemplazos):
		await mensaje(str(textos["rechazo"]))  # DeclineTrade
		return RECHAZADO
	var indice: int = await _elegir_del_equipo()
	var equipo: Array = SistemaGuardado.get_equipo()
	if indice < 0 or indice >= equipo.size() or not (equipo[indice] is BasePokemon):
		await mensaje(str(textos["rechazo"]))  # 255: DeclineTrade
		return RECHAZADO
	var saliente: BasePokemon = equipo[indice]
	if DatosIntercambio.especie_para_intercambio(saliente) != str(datos["especie_pedida"]):
		await mensaje(str(textos["no_es"]), true, reemplazos)  # NotRequestedMon
		return NO_ES
	var recibido := DatosIntercambio.crear_pokemon(datos, saliente.nivel)  # CreateInGameTradePokemon
	await _realizar_trueque(indice, saliente, recibido, str(datos["entrenador"]))
	SistemaGuardado.set_flag(bandera, true)
	await mensaje(str(textos["hecho"]), true, reemplazos)  # PleaseBeNiceToMon
	intercambio_realizado.emit(recibido)
	return HECHO


## DoInGameTradeScene: la escena, el cambio de ranura, la POKéDEX y la evolución por intercambio.
func _realizar_trueque(indice: int, saliente: BasePokemon, recibido: BasePokemon, entrenador: String) -> void:
	if is_instance_valid(admin):
		admin.cuadro_dialogo.cerrar()
	if con_escena:
		await Singleton.transicion("oscurecer")
		await EscenaIntercambio.intercambiar_en(get_tree(), saliente, recibido, entrenador)
	intercambiar_en_equipo(indice, recibido)
	var destino := EvolucionPokemon.especie_destino(recibido, EvolucionPokemon.Modo.INTERCAMBIO)
	if not destino.is_empty():
		if con_escena:
			await EscenaEvolucionAnim.ejecutar_en(get_tree(), recibido, destino, false, SistemaGuardado.get_equipo(), true)
		else:
			EvolucionPokemon.evolucionar(recibido, destino)
			EvolucionPokemon.registrar_evolucion(destino)
	if con_escena:
		await Singleton.transicion("aclarar")


## `sub_804BA94` + `sub_804BA18`: el recibido sustituye al del jugador en su ranura y su
## especie queda vista y atrapada en la POKéDEX (los huevos no).
static func intercambiar_en_equipo(indice: int, recibido: BasePokemon) -> void:
	var equipo: Array = SistemaGuardado.get_equipo()
	recibido.indice_orden_original = -1
	equipo[indice] = recibido
	SistemaGuardado.registrar_pokemon_atrapado(recibido.nombre_interno)


## SelectMonForNPCTrade: equipo en modo ELEGIR con fundidos (patrón de npc_inspector_motes.gd y
## npc_abuela_guarderia.gd). Devuelve el índice elegido o -1 si se cancela.
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
