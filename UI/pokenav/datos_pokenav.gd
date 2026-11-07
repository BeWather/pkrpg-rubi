extends RefCounted
class_name DatosPokenav

## Datos del POKéNAV: entrenadores registrados, Pokémon con cintas y luz de revancha.
## Los JSON se generan con herramientas/pokenav/generar_datos_pokenav.py.

const RUTA_ENTRENADORES: String = "res://BaseDatos/pokenav/entrenadores_pokenav.json"
const RUTA_CINTAS: String = "res://BaseDatos/pokenav/cintas_pokenav.json"
## FLAG_SYS_RIBBON_GET (ver sala_concurso.gd).
const BANDERA_CINTA_OBTENIDA: String = "cinta_obtenida"

static var _entrenadores: Array = []
static var _lineas_cintas: Dictionary = {}


static func entrenadores() -> Array:
	if _entrenadores.is_empty():
		_entrenadores = _leer(RUTA_ENTRENADORES) as Array
	return _entrenadores


## HasTrainerAlreadyBeenFought: por la bandera del NPC/evento o por la medalla del líder.
static func vencido(entrada: Dictionary) -> bool:
	var medalla: int = int(entrada.get("medalla", -1))
	if medalla >= 0 and SistemaGuardado.tiene_medalla(medalla):
		return true
	for bandera: Variant in entrada.get("banderas", []):
		if SistemaGuardado.get_flag(str(bandera)):
			return true
	return false


## sub_80F6C20: entrenadores ya vencidos, en el orden de la tabla.
static func entrenadores_registrados() -> Array:
	return entrenadores().filter(vencido)


## trainerRematches[i] != 0: el entrenador quiere revancha.
static func quiere_revancha(entrada: Dictionary) -> bool:
	return entrada.has("indice_revancha") and SistemaGuardado.get_revanchas().esta_lista(int(entrada["indice_revancha"]))


## DoesSomeoneWantRematchIn: algún entrenador del mapa `mapa` quiere revancha.
static func revancha_en_mapa(mapa: Node) -> bool:
	if mapa == null:
		return false
	var revanchas: SistemaRevanchas = SistemaGuardado.get_revanchas()
	if revanchas.indices_listos().is_empty():
		return false
	for nodo: Node in mapa.find_children("*", "Node2D", true, false):
		if "entrenador_id" in nodo:
			var indice: int = revanchas.indice_por_primer_id(int(nodo.get("entrenador_id")))
			if indice >= 0 and revanchas.esta_lista(indice):
				return true
	return false


## Equipo y después cajas, sin HUEVOS: [{pokemon, caja}] (caja -1 = equipo).
static func todos_los_pokemon() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for miembro: Variant in SistemaGuardado.get_equipo():
		_agregar(lista, miembro, -1)
	var cajas: Array = SistemaGuardado.obtener_cajas_pc()
	for c in cajas.size():
		for miembro: Variant in cajas[c]:
			_agregar(lista, miembro, c)
	return lista


static func _agregar(lista: Array[Dictionary], miembro: Variant, caja: int) -> void:
	var pokemon: BasePokemon = miembro as BasePokemon
	if pokemon != null and not pokemon.huevo:
		lista.append({"pokemon": pokemon, "caja": caja})


## Opción CINTAS (FLAG_SYS_RIBBON_GET): la bandera, o algún Pokémon que ya tenga cintas.
static func cintas_disponibles() -> bool:
	return SistemaGuardado.get_flag(BANDERA_CINTA_OBTENIDA) or not pokemon_con_cintas().is_empty()


static func pokemon_con_cintas() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for dato: Dictionary in todos_los_pokemon():
		if not (dato["pokemon"] as BasePokemon).cintas.is_empty():
			lista.append(dato)
	return lista


## Índices de gPokenavRibbonsIconGfx de las cintas del Pokémon, en el orden de la ROM.
static func indices_cintas(pokemon: BasePokemon) -> Array[int]:
	var indices: Array[int] = []
	for clave: Variant in pokemon.cintas:
		var cinta: Dictionary = Singleton.CINTAS_POKEMON.get(str(clave), {})
		if not cinta.is_empty():
			indices.append(int(cinta["orden"]))
	indices.sort()
	return indices


## gRibbonDescriptions: las dos líneas de la cinta `indice`.
static func lineas_cinta(indice: int) -> Array:
	if _lineas_cintas.is_empty():
		_lineas_cintas = _leer(RUTA_CINTAS) as Dictionary
	return _lineas_cintas.get(str(indice), ["", ""])


static func _leer(ruta: String) -> Variant:
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		push_error("[POKENAV] No se pudo abrir %s" % ruta)
		return null
	return JSON.parse_string(archivo.get_as_text())
