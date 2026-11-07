class_name ObjetosLlevados
extends RefCounted

## Lógica de objetos llevados (equipados) por los Pokémon.
## Funciones estáticas sin UI: las usan la mochila (DAR) y la pantalla
## de equipo, y servirán para la futura opción de equipo "OBJETO > DAR/QUITAR".
##
## El objeto llevado se guarda en BasePokemon.objeto como nombre_interno del
## objeto (en mayúsculas, igual que en la mochila); "" = no lleva nada.
##
## Referencia: pokeruby src/item_menu.c (HandlePopupMenuAction_Give),
## src/party_menu.c (PartyMenuTryGiveMonHeldItem y
## PartyMenuTryGiveMonHeldItem_806EACC).

## Resultado de intentar dar un objeto a un Pokémon.
enum ResultadoDar {
	EQUIPADO,          ## No llevaba nada: se le equipa y se gasta 1 de la mochila.
	YA_LLEVA_CARTA,    ## Lleva una CARTA: hay que quitarla antes (no cambia nada).
	YA_LLEVA_OBJETO,   ## Lleva otro objeto: hay que preguntar si se intercambian.
	ERROR,             ## Datos inválidos o el objeto no está en la mochila.
}

## Bolsillos de la mochila (0-based, como en mochila.gd / SistemaGuardado).
const BOLSILLO_OBJETOS: int = 0
const BOLSILLO_MT_MO: int = 2
const BOLSILLO_BAYAS: int = 3
const BOLSILLO_CLAVE: int = 4

## Huecos por bolsillo (BAG_*_COUNT en include/constants/global.h). No limitan
## la mochila: el juego no comprueba si está llena.
const HUECOS_POR_BOLSILLO: Array[int] = [20, 16, 64, 46, 20]

## Valor de Objetos.uso_campo de las cartas.
const USO_CARTA: String = "CARTA"


# ─── Consultas ───────────────────────────────────────────────────────────────

## true si el objeto se puede llevar. En Ruby no se pueden llevar los objetos
## con importance != 0: objetos clave y MO. Las MT sí se pueden llevar.
static func se_puede_llevar(item: Dictionary, bolsillo: int) -> bool:
	if bolsillo == BOLSILLO_CLAVE:
		return false
	if bolsillo == BOLSILLO_MT_MO and es_mo(item):
		return false
	return true


## true si el objeto del bolsillo MT/MO es una MO (nombre_interno "MO.."/"HM.."
## o icono de MO en la lista).
static func es_mo(item: Dictionary) -> bool:
	var nombre_interno: String = str(item.get("nombre_interno", "")).strip_edges().to_upper()
	if nombre_interno.begins_with("MO") or nombre_interno.begins_with("HM"):
		return true
	return str(item.get("icono", "")).contains("txt_mo.png")


## true si el objeto (nombre_interno) es una CARTA (Objetos.uso_campo = CARTA).
static func es_carta(nombre_interno: String) -> bool:
	var datos: Dictionary = _datos_bd(nombre_interno)
	return datos.get("uso_campo") is String and datos.get("uso_campo") == USO_CARTA


## true si el Pokémon lleva algún objeto.
static func lleva_objeto(pokemon: BasePokemon) -> bool:
	return pokemon != null and not _normalizar(pokemon.objeto).is_empty()


## Nombre mostrable (tabla Objetos.nombre) de un objeto por su nombre_interno.
static func nombre_objeto(nombre_interno: String) -> String:
	var datos: Dictionary = _datos_bd(nombre_interno)
	if datos.get("nombre") is String:
		return (datos.get("nombre") as String).strip_edges().to_upper()
	return _normalizar(nombre_interno)


## Bolsillo (0-based) al que va el objeto, o -1 si no tiene o no existe en la BD.
## Las cartas normales van al bolsillo Objetos (0).
static func bolsillo_de(nombre_interno: String) -> int:
	var datos: Dictionary = _datos_bd(nombre_interno)
	var bolsillo_bd: Variant = datos.get("bolsillo_id")
	if bolsillo_bd == null:
		return -1
	return int(bolsillo_bd) - 1


## true si el jugador no tiene ningún Pokémon en el equipo.
static func equipo_vacio() -> bool:
	if SistemaGuardado == null or SistemaGuardado.datos_vivos == null:
		return true
	return SistemaGuardado.datos_vivos.equipo_pokemon.is_empty()


# ─── Acciones ────────────────────────────────────────────────────────────────

## Primera parte de PartyMenuTryGiveMonHeldItem: si el Pokémon no lleva nada
## se le equipa `nombre_interno` y se quita 1 del bolsillo `bolsillo`. Si ya
## lleva algo no se toca nada y se devuelve qué mensaje toca mostrar.
static func dar_objeto(pokemon: BasePokemon, nombre_interno: String, bolsillo: int) -> ResultadoDar:
	var nuevo: String = _normalizar(nombre_interno)
	if pokemon == null or nuevo.is_empty():
		return ResultadoDar.ERROR
	if lleva_objeto(pokemon):
		if es_carta(pokemon.objeto):
			return ResultadoDar.YA_LLEVA_CARTA
		return ResultadoDar.YA_LLEVA_OBJETO
	if not SistemaGuardado.quitar_objeto_jugador(nuevo, 1, bolsillo):
		push_warning("[OBJETOS LLEVADOS] %s no está en el bolsillo %d" % [nuevo, bolsillo])
		return ResultadoDar.ERROR
	# Con una CARTA, quien llama abre PALABRAS FÁCILES para escribirla
	# (PantallaEquipoControlador._escribir_carta).
	pokemon.objeto = nuevo
	pokemon.carta = {}
	return ResultadoDar.EQUIPADO


## PartyMenuTryGiveMonHeldItem_806EACC (respuesta SÍ): quita 1 del objeto nuevo,
## guarda en la mochila el que llevaba y le equipa el nuevo. A diferencia de
## Ruby no se comprueba si la mochila está llena: el antiguo siempre se guarda.
## Sólo retorna false con datos inválidos.
static func intercambiar_objeto(pokemon: BasePokemon, nombre_interno: String, bolsillo: int) -> bool:
	var nuevo: String = _normalizar(nombre_interno)
	if pokemon == null or nuevo.is_empty() or not lleva_objeto(pokemon):
		return false
	var antiguo: String = _normalizar(pokemon.objeto)
	if not _tiene_bolsillo(antiguo):
		return false
	if not SistemaGuardado.quitar_objeto_jugador(nuevo, 1, bolsillo):
		push_warning("[OBJETOS LLEVADOS] %s no está en el bolsillo %d" % [nuevo, bolsillo])
		return false
	SistemaGuardado.dar_objeto_jugador(antiguo, 1)
	pokemon.objeto = nuevo
	pokemon.carta = {}
	return true


## Quita el objeto que lleva el Pokémon y lo guarda en la mochila (opción
## OBJETO > QUITAR). A diferencia de Ruby no se comprueba si la mochila está
## llena. Devuelve false si no llevaba nada o el objeto no existe en la BD.
static func quitar_objeto(pokemon: BasePokemon) -> bool:
	if not lleva_objeto(pokemon):
		return false
	var antiguo: String = _normalizar(pokemon.objeto)
	if not _tiene_bolsillo(antiguo):
		return false
	SistemaGuardado.dar_objeto_jugador(antiguo, 1)
	pokemon.objeto = ""
	# TakeMailFromMon: la carta vuelve a la mochila en blanco.
	pokemon.carta = {}
	return true


## true si el objeto tiene bolsillo y se puede guardar con dar_objeto_jugador.
static func _tiene_bolsillo(nombre_interno: String) -> bool:
	var bolsillo: int = bolsillo_de(nombre_interno)
	if bolsillo < 0 or bolsillo >= HUECOS_POR_BOLSILLO.size():
		push_warning("[OBJETOS LLEVADOS] %s no tiene bolsillo válido en la BD" % nombre_interno)
		return false
	SistemaGuardado.inicializar_mochila_estructura()
	return true


## Fila de la tabla Objetos, incluidos los campos específicos de objetos llevados.
static func _datos_bd(nombre_interno: String) -> Dictionary:
	var clave: String = _normalizar(nombre_interno)
	if clave.is_empty() or DatabaseManager == null or not DatabaseManager.esta_conectado():
		return {}
	return DatabaseManager.obtener_datos_objeto(clave)


static func _normalizar(nombre_interno: String) -> String:
	var clave: String = nombre_interno.strip_edges().to_upper()
	return "" if clave == "NONE" else clave


## Atomic live held-item exchange: no bag mutation, copying or presentation yield.
## Battle caller owns source targeting/mode/ability authorization.
static func intercambiar_en_combate(actor: BasePokemon, target: BasePokemon) -> bool:
	if actor==null or target==null or actor==target:return false
	var before_actor: String=actor.objeto
	var before_target: String=target.objeto
	if before_actor.is_empty() and before_target.is_empty():return false
	if es_carta(before_actor) or es_carta(before_target):return false
	if _normalizar(before_actor) in ["BAYAENIGMA","ENIGMABERRY"] or _normalizar(before_target) in ["BAYAENIGMA","ENIGMABERRY"]:return false
	actor.objeto=before_target
	target.objeto=before_actor
	return true

## Effective battle-held item; saved party ownership is not Knock Off state.
static func en_combate(pokemon: BasePokemon) -> String:
	return BattleHeldItemRules.held(pokemon)
