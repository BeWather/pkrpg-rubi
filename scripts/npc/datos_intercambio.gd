class_name DatosIntercambio
extends RefCounted

## Tabla de intercambios con NPC de Rubí (`gIngameTrades`, pokeruby `src/trade.c`) y la
## creación del Pokémon que da el NPC (`_CreateInGameTradePokemon`). Los datos viven en
## `BaseDatos/intercambios_npc.json` (ver `campos` allí); el guion lo ejecuta `IntercambioNpc`.

const RUTA_TABLA: String = "res://BaseDatos/intercambios_npc.json"
const BOLA_INTERCAMBIO: String = "POKEBALL"
## `friendship = 70` de `sub_804BA94`: el Pokémon recibido empieza con 70 de amistad.
const AMISTAD_INTERCAMBIO: int = 70
const TEXTOS_OBLIGATORIOS: PackedStringArray = ["oferta", "hecho", "no_es", "rechazo", "completado"]

static var _tabla: Dictionary = {}
static var _cargada: bool = false


## Todos los intercambios: id -> datos.
static func todos() -> Dictionary:
	_cargar()
	return _tabla


## Datos del intercambio `id` ("ARBORADA"...), o {} si no existe.
static func obtener(id: String) -> Dictionary:
	_cargar()
	return _tabla.get(id, {}) as Dictionary


## Fuerza la relectura del JSON (pruebas).
static func recargar() -> void:
	_cargada = false
	_tabla = {}


## `GetTradeSpecies`: especie (nombre_interno) que cuenta para el trueque. Un HUEVO no es
## ninguna especie ("").
static func especie_para_intercambio(pokemon: BasePokemon) -> String:
	if pokemon == null or pokemon.huevo:
		return ""
	return pokemon.nombre_interno


## Nombre mostrado de una especie (`gSpeciesNames`).
static func nombre_especie(nombre_interno: String) -> String:
	var fila: Dictionary = DatabaseManager.obtener_datos_pokemon(nombre_interno)
	return str(fila.get("nombre", nombre_interno)) if not fila.is_empty() else nombre_interno


## Marcadores de los textos del NPC: {mon_pedido}/{mon_jugador} = especie pedida (STR_VAR_1 de
## `GetInGameTradeSpeciesInfo`) y {mon_ofrecido}/{mon_npc} = la que da (STR_VAR_2).
static func reemplazos_textos(datos: Dictionary) -> Dictionary:
	var pedido := nombre_especie(str(datos.get("especie_pedida", "")))
	var ofrecido := nombre_especie(str(datos.get("especie_ofrecida", "")))
	return {
		"{mon_pedido}": pedido, "{mon_jugador}": pedido,
		"{mon_ofrecido}": ofrecido, "{mon_npc}": ofrecido,
	}


## `_CreateInGameTradePokemon`: el Pokémon que da el NPC, al nivel del que entrega el jugador
## (`level` de `CreateMon`) y con lo que fija la tabla: apodo, EO (nombre, ID y sexo), IVs,
## personalidad (naturaleza, sexo), habilidad (`secondAbility`), condiciones y objeto.
## Los movimientos son los de aprendizaje por nivel de la especie, como `CreateMon`. Empieza
## con 70 de amistad, lugar de encuentro INTERCAMBIO (`MET_LOCATION` 0xFE) y una POKé BALL.
static func crear_pokemon(datos: Dictionary, nivel: int) -> BasePokemon:
	var especie := str(datos.get("especie_ofrecida", ""))
	var pokemon := BasePokemon.new(especie, nivel, str(datos.get("entrenador", "")))
	var ivs: Dictionary = datos.get("ivs", {})
	# aplicar_snapshot recalcula las estadísticas con los IVs fijados.
	pokemon.aplicar_snapshot({
		"mote": str(datos.get("mote", "")),
		"naturaleza": str(datos.get("naturaleza", pokemon.naturaleza)),
		"sexo": str(datos.get("sexo", pokemon.sexo)),
		"habilidad": _habilidad(especie, bool(datos.get("segunda_habilidad", false)), pokemon.habilidad),
		"objeto": str(datos.get("objeto", "")),
		"entrenador_original": str(datos.get("entrenador", "")),
		"encuentro_lugar": Lugares.INTERCAMBIO,
		"encuentro_bola": BOLA_INTERCAMBIO,
		"iv_ps": int(ivs.get("ps", pokemon.iv_ps)),
		"iv_ataque": int(ivs.get("ataque", pokemon.iv_ataque)),
		"iv_defensa": int(ivs.get("defensa", pokemon.iv_defensa)),
		"iv_velocidad": int(ivs.get("velocidad", pokemon.iv_velocidad)),
		"iv_ataque_especial": int(ivs.get("ataque_especial", pokemon.iv_ataque_especial)),
		"iv_defensa_especial": int(ivs.get("defensa_especial", pokemon.iv_defensa_especial)),
	})
	pokemon.entrenador_id = int(datos.get("entrenador_id", 0))
	pokemon.entrenador_sexo = str(datos.get("entrenador_sexo", "M"))
	pokemon.personalidad = int(datos.get("personalidad", pokemon.personalidad))
	pokemon.felicidad = AMISTAD_INTERCAMBIO
	pokemon.encuentro_nivel = nivel
	# El tipo de PODER OCULTO depende de los IVs, que el constructor sorteó antes de fijarlos.
	pokemon.tipo_poder_oculto = pokemon.get_poder_oculto(pokemon.iv_ps, pokemon.iv_ataque, pokemon.iv_defensa,
			pokemon.iv_velocidad, pokemon.iv_ataque_especial, pokemon.iv_defensa_especial)
	var condiciones: Dictionary = datos.get("condiciones", {})
	pokemon.carisma = int(condiciones.get("carisma", 0))
	pokemon.belleza = int(condiciones.get("belleza", 0))
	pokemon.dulzura = int(condiciones.get("dulzura", 0))
	pokemon.ingenio = int(condiciones.get("ingenio", 0))
	pokemon.dureza = int(condiciones.get("dureza", 0))
	return pokemon


## `MON_DATA_ALT_ABILITY`: la segunda habilidad de la especie si `segunda` y la tiene; si no, la primera.
static func _habilidad(especie: String, segunda: bool, por_defecto: String) -> String:
	var fila: Dictionary = DatabaseManager.obtener_datos_pokemon(especie)
	if fila.is_empty():
		return por_defecto
	var primera := "" if fila.get("habilidad_1") == null else str(fila["habilidad_1"]).strip_edges()
	var segunda_hab := "" if fila.get("habilidad_2") == null else str(fila["habilidad_2"]).strip_edges()
	if segunda and not segunda_hab.is_empty():
		return segunda_hab
	return primera if not primera.is_empty() else por_defecto


static func _cargar() -> void:
	if _cargada:
		return
	_cargada = true
	var archivo := FileAccess.open(RUTA_TABLA, FileAccess.READ)
	if archivo == null:
		push_error("[DatosIntercambio] No se pudo abrir %s" % RUTA_TABLA)
		return
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if datos is Dictionary and (datos as Dictionary).get("intercambios") is Dictionary:
		_tabla = (datos as Dictionary)["intercambios"]
	else:
		push_error("[DatosIntercambio] JSON inválido en %s" % RUTA_TABLA)
