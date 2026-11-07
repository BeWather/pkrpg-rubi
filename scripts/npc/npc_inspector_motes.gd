@tool
## npc_inspector_motes.gd
## INSPECTOR de MOTES de CIUDAD PORTUAL (pokeruby
## SlateportCity_NameRatersHouse_EventScript_NameRater: lock + faceplayer):
## 1. «Estaré encantado de evaluar el nombre de tu POKéMON» SÍ/NO; NO → «vuelve cuando quieras».
## 2. SÍ → «¿Qué nombre de POKéMON quieres que adivine?» y abre el equipo (SelectMonForNPCTrade,
##    `Singleton.ModoPEquipo.ELEGIR`). Cancelar (255) → «vuelve cuando quieras».
## 3. Un HUEVO → «¡Esto es sólo un HUEVO!».
## 4. Un POKéMON cuyo ENTRENADOR ORIGINAL no es el jugador (TV_CheckMonOTIDEqualsPlayerID /
##    MonOTNameMatchesPlayer) → «¡He aquí un mote magnífico!», sin cambiar nada.
## 5. Si no, «¿no crees que podríamos encontrar un nombre aún mejor?» SÍ/NO (NO → «vuelve
##    cuando quieras»), «¿Cuál será el nuevo nombre?» y la pantalla de nombre
##    (Common_EventScript_NameReceivedPartyMon, `escenas/entrada_nombre`). Con el nombre distinto
##    «será {mote}… mucho mejor»; con el mismo (o vacío/cancelado, que vuelve al nombre de la
##    especie) «no parece muy diferente… y sin embargo es muchísimo mejor».
## Con el mote cambiado, `TV_PutNameRaterShowOnTheAirIfNicnkameChanged` graba LA HORA DEL INSPECTOR
## DE LOS MOTES para la tele (ProgramasTV.tras_cambiar_mote).
## {mote} es el nombre mostrado (mote o, sin él, el de la especie).
## Bloqueo del jugador y diálogo: patrón de npc_reportero_museo.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const TEXTO_PRESENTACION: String = "PORTUAL_INSPECTOR_PRESENTACION"
const TEXTO_ELEGIR: String = "PORTUAL_INSPECTOR_ELEGIR"
const TEXTO_VUELVE: String = "PORTUAL_INSPECTOR_VUELVE"
const TEXTO_PROPONE: String = "PORTUAL_INSPECTOR_PROPONE"
const TEXTO_HUEVO: String = "PORTUAL_INSPECTOR_HUEVO"
const TEXTO_MAGNIFICO: String = "PORTUAL_INSPECTOR_MAGNIFICO"
const TEXTO_NUEVO_NOMBRE: String = "PORTUAL_INSPECTOR_NUEVO_NOMBRE"
const TEXTO_IGUAL: String = "PORTUAL_INSPECTOR_IGUAL"
const TEXTO_MEJOR: String = "PORTUAL_INSPECTOR_MEJOR"

const ESCENA_EQUIPO: String = "res://UI/equipo/pantalla-equipo.tscn"
const ESCENA_ENTRADA_NOMBRE: String = "res://escenas/entrada_nombre/entrada_nombre.tscn"
## POKEMON_NAME_LENGTH (misma constante que battle_presentation_controller.gd).
const MAX_CARACTERES_MOTE: int = 10
## entrada_nombre.gd TipoObjetivo.POKEMON y SexoPokemon.
const ENTRADA_NOMBRE_POKEMON: int = 2
const ENTRADA_NOMBRE_SEXO: Dictionary = {"M": 1, "F": 2}

## Si es válido sustituye a la pantalla de equipo: devuelve el índice elegido o -1 (tests).
var selector_equipo: Callable = Callable()
## Si es válido sustituye a la pantalla de nombre: recibe el BasePokemon y devuelve el mote
## escrito ("" = cancelado o vacío) (tests).
var selector_nombre: Callable = Callable()

signal _equipo_cerrado
signal _nombre_cerrado(nombre: String)


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_conversar()


func _conversar() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	await _guion()
	nodo_administrador.cuadro_dialogo.cerrar()
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


func _guion() -> void:
	if not await _preguntar(tr(TEXTO_PRESENTACION)):
		await _mensaje(tr(TEXTO_VUELVE))  # DeclineNameRate
		return
	await _mensaje(tr(TEXTO_ELEGIR))  # ChooseMonToRate
	var indice: int = await _elegir_del_equipo()
	var equipo: Array = SistemaGuardado.get_equipo()
	if indice < 0 or indice >= equipo.size() or not (equipo[indice] is BasePokemon):
		await _mensaje(tr(TEXTO_VUELVE))
		return
	var pokemon: BasePokemon = equipo[indice]
	if pokemon.huevo:
		await _mensaje(tr(TEXTO_HUEVO))  # CantRateEgg
		return
	var antes: String = pokemon.get_nombre_mostrar()
	if not es_del_jugador(pokemon):
		await _mensaje(_con_mote(TEXTO_MAGNIFICO, antes))  # PlayerNotMonsOT
		return
	if not await _preguntar(_con_mote(TEXTO_PROPONE, antes)):
		await _mensaje(tr(TEXTO_VUELVE))
		return
	await _mensaje(tr(TEXTO_NUEVO_NOMBRE))  # ChangeNickname
	var nuevo: String = await _pedir_mote(pokemon)
	pokemon.mote = nuevo
	var despues: String = pokemon.get_nombre_mostrar()
	if despues != antes:
		ProgramasTV.tras_cambiar_mote(pokemon)  # TV_PutNameRaterShowOnTheAirIfNicnkameChanged
	await _mensaje(_con_mote(TEXTO_MEJOR if despues != antes else TEXTO_IGUAL, despues))


## El jugador es el ENTRENADOR ORIGINAL (mismo ID y mismo nombre): solo entonces se renombra.
static func es_del_jugador(pokemon: BasePokemon) -> bool:
	var jugador_datos: Dictionary = SistemaGuardado.datos_vivos.jugador
	var nombre: String = str(jugador_datos.get("nombre", "")).strip_edges()
	return pokemon.entrenador_id == int(jugador_datos.get("id", 0)) \
		and pokemon.entrenador_original.strip_edges() == nombre


func _con_mote(clave: String, mote: String) -> String:
	return tr(clave).replace("{mote}", mote)


## Mensaje ya traducido en un cuadro nuevo (tras una pregunta, o en el primer mensaje).
func _mensaje(texto: String) -> void:
	nodo_administrador.cuadro_dialogo.mostrar(texto, true, false, _mensaje_terminado.emit)
	await _mensaje_terminado


## SÍ/NO sobre un texto ya traducido (un mote escrito por el jugador no debe pasar por tr()).
func _preguntar(texto: String) -> bool:
	var dialogo: NinePatchRect = nodo_administrador.cuadro_dialogo
	# preguntaSiNo() exige el cuadro en IDLE o ESPERANDO_REINGRESO.
	dialogo.cerrar()
	dialogo.preguntaSiNo(texto)
	var respuesta: String = ""
	while respuesta.is_empty():
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			respuesta = str(parametros[0]) if not parametros.is_empty() else "N"
	return respuesta == "Y"


## SelectMonForNPCTrade: equipo en modo ELEGIR con fundidos (patrón npc_abuela_guarderia.gd).
## Devuelve el índice elegido o -1 si se cancela.
func _elegir_del_equipo() -> int:
	if selector_equipo.is_valid():
		return int(selector_equipo.call())
	var capa := get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	if capa == null:
		return -1
	nodo_administrador.cuadro_dialogo.cerrar()
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


## Common_EventScript_NameReceivedPartyMon: la pantalla de nombre en modo POKéMON
## (patrón battle_presentation_controller.pedir_mote). Devuelve "" si se cancela o se
## confirma vacío: el POKéMON recupera el nombre de su especie.
func _pedir_mote(pokemon: BasePokemon) -> String:
	if selector_nombre.is_valid():
		return str(selector_nombre.call(pokemon)).strip_edges()
	var capa := get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	if capa == null:
		return ""
	nodo_administrador.cuadro_dialogo.cerrar()
	await Singleton.transicion("oscurecer")
	var entrada := (load(ESCENA_ENTRADA_NOMBRE) as PackedScene).instantiate() as Control
	entrada.z_index = 6
	entrada.set("sexo_pokemon", int(ENTRADA_NOMBRE_SEXO.get(pokemon.sexo, 0)))
	var respuesta := {"lista": false, "nombre": ""}
	entrada.connect("nombre_confirmado", func(nombre: String) -> void:
		respuesta["lista"] = true
		respuesta["nombre"] = nombre
		_nombre_cerrado.emit(nombre)
	, CONNECT_ONE_SHOT)
	entrada.connect("cancelado", func() -> void:
		respuesta["lista"] = true
		_nombre_cerrado.emit("")
	, CONNECT_ONE_SHOT)
	capa.add_child(entrada)
	entrada.call(
		"configurar",
		"¿Mote de %s?" % pokemon.get_nombre_mostrar(),
		MAX_CARACTERES_MOTE,
		false,
		ENTRADA_NOMBRE_POKEMON,
		maxi(pokemon.numero_nacional, 1)
	)
	await Singleton.transicion("aclarar")
	if not bool(respuesta["lista"]):
		await _nombre_cerrado
	await Singleton.transicion("oscurecer")
	entrada.queue_free()
	await Singleton.transicion("aclarar")
	return str(respuesta["nombre"]).strip_edges()
