@tool
## npc_quitamovimientos.gd
## QUITA-MOVIMIENTOS de CIUDAD CALAGUA (pokeruby LilycoveCity_MoveDeletersHouse_EventScript_MoveDeleter:
## lockall + Common_Movement_FacePlayer; en la ROM española «QUITA-MOVIMIENTOS»):
## 1. «¿Quieres que me ocupe de los tuyos?» SÍ/NO. NO → «vuelve por aquí…».
## 2. SÍ → «¿Qué POKéMON debería olvidar algún movimiento?» y abre el equipo (SelectMonForNPCTrade,
##    `Singleton.ModoPEquipo.ELEGIR`). Cancelar (255) → «vuelve por aquí…».
## 3. Un HUEVO → «¿Cómo? Un HUEVO no puede saber ningún movimiento» (fin).
## 4. Con un solo movimiento → «{mote} sólo sabe un movimiento…» (fin).
## 5. «¿Qué movimiento debería olvidar?» y la ficha de movimientos (`special SelectMove`, la ficha
##    de `FichaOlvidarMovimiento` sin la fila del movimiento nuevo). B (VAR_0x8005 = 4) vuelve al
##    paso 2 para elegir de nuevo el POKéMON. Se puede borrar también un movimiento de MO.
## 6. «¿{movimiento} de {mote}? ¿Ése quieres? ¿De verdad?» SÍ/NO. NO → «vuelve por aquí…». SÍ →
##    DeleteMonMove (los demás movimientos suben un hueco), MUS_MOVE_DELETED y «¡Ha salido de
##    perlas! {mote} ha olvidado completamente {movimiento}».
## {mote} = mote o nombre de la especie; {movimiento} = nombre del movimiento en mayúsculas.
## Bloqueo del jugador y diálogo: patrón de npc_inspector_motes.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const TEXTO_PRESENTACION: String = "CALAGUA_QUITAMOV_PRESENTACION"
const TEXTO_QUE_POKEMON: String = "CALAGUA_QUITAMOV_QUE_POKEMON"
const TEXTO_QUE_MOVIMIENTO: String = "CALAGUA_QUITAMOV_QUE_MOVIMIENTO"
const TEXTO_SOLO_UNO: String = "CALAGUA_QUITAMOV_SOLO_UNO"
const TEXTO_CONFIRMA: String = "CALAGUA_QUITAMOV_CONFIRMA"
const TEXTO_OLVIDADO: String = "CALAGUA_QUITAMOV_OLVIDADO"
const TEXTO_VUELVE: String = "CALAGUA_QUITAMOV_VUELVE"
const TEXTO_HUEVO: String = "CALAGUA_QUITAMOV_HUEVO"

const ESCENA_EQUIPO: String = "res://UI/equipo/pantalla-equipo.tscn"
const ESCENA_FICHA: String = "res://UI/poke-info/ficha_olvidar_movimiento.tscn"
## Por encima de la pantalla de equipo y del cuadro de mensajes (como en PantallaEquipoControlador).
const Z_FICHA: int = 5
## MUS_MOVE_DELETED (MUS_ME_WASURE, 378_movimiento_olvidado.ogg; clave de Singleton.TEMAS_REGISTRADOS).
const FANFARRIA: String = "MOVIMIENTO_OLVIDADO"

## Si es válido sustituye a la pantalla de equipo: devuelve el índice elegido o -1 (tests).
var selector_equipo: Callable = Callable()
## Si es válido sustituye a la ficha de movimientos: recibe el BasePokemon y devuelve el índice
## del movimiento (0-3) o FichaOlvidarMovimiento.INDICE_NUEVO si se cancela (tests).
var selector_movimiento: Callable = Callable()
## false omite la fanfarria de MUS_MOVE_DELETED (tests).
var con_fanfarria: bool = true

signal _equipo_cerrado


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
	mirar_jugador()  # Common_Movement_FacePlayer
	_bloquear_jugador(true)
	await _guion()
	nodo_administrador.cuadro_dialogo.cerrar()
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


func _guion() -> void:
	if not await _preguntar(tr(TEXTO_PRESENTACION)):
		await _mensaje(tr(TEXTO_VUELVE))  # ComeAgain
		return
	while true:  # ChooseMonAndMoveToForget
		await _mensaje(tr(TEXTO_QUE_POKEMON))
		var indice: int = await _elegir_del_equipo()
		var equipo: Array = SistemaGuardado.get_equipo()
		if indice < 0 or indice >= equipo.size() or not (equipo[indice] is BasePokemon):
			await _mensaje(tr(TEXTO_VUELVE))
			return
		var pokemon: BasePokemon = equipo[indice]
		if pokemon.huevo:
			await _mensaje(tr(TEXTO_HUEVO))  # EggCantForgetMoves
			return
		var mote: String = pokemon.get_nombre_mostrar()
		if pokemon.movimientos.size() <= 1:
			await _mensaje(_con(TEXTO_SOLO_UNO, mote, ""))  # MonOnlyKnowsOneMove
			return
		await _mensaje(tr(TEXTO_QUE_MOVIMIENTO))
		var cual: int = await _elegir_movimiento(pokemon)
		if cual < 0 or cual >= pokemon.movimientos.size():
			continue  # B: vuelve a elegir el POKéMON
		var nombre_movimiento: String = pokemon.movimientos[cual].nombre.to_upper()
		if not await _preguntar(_con(TEXTO_CONFIRMA, mote, nombre_movimiento)):
			await _mensaje(tr(TEXTO_VUELVE))
			return
		pokemon.movimientos.remove_at(cual)  # DeleteMonMove
		if con_fanfarria:
			await Fanfarria.reproducir(self, FANFARRIA)
		await _mensaje(_con(TEXTO_OLVIDADO, mote, nombre_movimiento))
		return


func _con(clave: String, mote: String, movimiento: String) -> String:
	return tr(clave).replace("{mote}", mote).replace("{movimiento}", movimiento)


## Mensaje ya traducido en un cuadro nuevo.
func _mensaje(texto: String) -> void:
	nodo_administrador.cuadro_dialogo.mostrar(texto, true, false, _mensaje_terminado.emit)
	await _mensaje_terminado


## SÍ/NO sobre un texto ya traducido (lleva el mote y el movimiento ya sustituidos).
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


## SelectMonForNPCTrade: equipo en modo ELEGIR con fundidos (patrón npc_inspector_motes.gd).
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


## special SelectMove: la ficha de movimientos del POKéMON con fundidos a negro. Devuelve el índice
## elegido (0-3) o FichaOlvidarMovimiento.INDICE_NUEVO si se cancela con B.
func _elegir_movimiento(pokemon: BasePokemon) -> int:
	if selector_movimiento.is_valid():
		return int(await selector_movimiento.call(pokemon))
	var capa := get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	if capa == null:
		return FichaOlvidarMovimiento.INDICE_NUEVO
	nodo_administrador.cuadro_dialogo.cerrar()
	var ficha := (load(ESCENA_FICHA) as PackedScene).instantiate() as FichaOlvidarMovimiento
	ficha.z_index = Z_FICHA
	capa.add_child(ficha)
	var indice: int = await ficha.elegir(pokemon, null)
	ficha.queue_free()
	return indice
