extends RefCounted
class_name DatosInicioBatalla

const CLAVES_CONOCIDAS: PackedStringArray = [
	"tipo",
	"formato",
	"ruleset",
	"tema_grafico",
	"tema_grafico_frente",
	"escenario",
	"terreno",
	"entrenador",
	"pokemon_salvaje",
	"equipo_jugador",
	"equipo_rival",
	"ubicacion",
	"puede_huir",
	"permite_captura",
	"balls_zona",
	"comentario",
	"clima",
]

## Extra que marca el primer combate (BATTLE_TYPE_FIRST_BATTLE).
const EXTRA_PRIMER_COMBATE: String = "primer_combate"
## Extra que marca el combate tutorial de BLASCO (BATTLE_TYPE_WALLY_TUTORIAL).
const EXTRA_TUTORIAL_BLASCO: String = "tutorial_blasco"
## Extra: los mensajes no esperan A/B; siguen solos tras una pausa (los {PAUSE}
## de Rubí en un combate que el jugador solo mira).
const EXTRA_TEXTOS_AUTOMATICOS: String = "textos_automaticos"
## Extra que marca el combate contra el Pokémon errante (BATTLE_TYPE_ROAMER).
const EXTRA_ERRANTE: String = "errante"
## Extra que marca un combate de la TORRE BATALLA (BATTLE_TYPE_BATTLE_TOWER): sin EXP, dinero, frase de derrota ni
## objetos de la MOCHILA, y sin registrar en la POKéDEX a los rivales; perder no lleva al punto de curación.
const EXTRA_TORRE_BATALLA: String = "torre_batalla"
## `terreno` sin fijar.
const TERRENO_NINGUNO: int = -1

var tipo: Singleton.TipoBatalla = Singleton.TipoBatalla.SALVAJE_TEST
## Plan 20260912 (Alcance 1): SIMPLE/DOBLE — slots activos por lado.
var formato: Singleton.FormatoBatalla = Singleton.FormatoBatalla.SIMPLE
## Plan 20260912 (Alcance 1): NORMAL/ZONA_SALVAJE. SIN_EQUIPO no se pide: se
## deriva del estado real del equipo dentro de batalla.gd.
var ruleset: Singleton.RulesetBatalla = Singleton.RulesetBatalla.NORMAL
var tema_grafico: Singleton.TemaBatalla = Singleton.TemaBatalla.NO_TIENE
var tema_grafico_frente: Singleton.TemaBatallaFrente = Singleton.TemaBatallaFrente.BASICO
## Id del escenario de batalla (fondo, suelo y entrada) resuelto como en Rubí
## (EscenarioBatalla.resolver_escenario). Vacío: batalla.gd usa el mapeo legado
## de `tema_grafico` (lanzador de depuración).
var escenario: String = ""
## gBattleTerrain (EscenarioBatalla.Terreno) del combate: decide la animación de
## la tira de entrada (AnimacionEntradaBatalla). TERRENO_NINGUNO: batalla.gd lo
## deduce del escenario o, sin él, del tema gráfico legado.
var terreno: int = TERRENO_NINGUNO
var entrenador: DatosEntrenador = null
var pokemon_salvaje_nombre_interno: String = ""
var pokemon_salvaje_nivel: int = 1
## Snapshot completo del salvaje tal como lo capturó el editor de pruebas.
## Vacío en batallas de juego normal; usado por batalla.gd para aplicar IVs,
## naturaleza, movimientos, etc. vía BasePokemon.aplicar_snapshot().
var pokemon_salvaje_snapshot: Dictionary = {}
var equipo_jugador: Array[BasePokemon] = []
## Equipo rival ya construido. Cuando está poblado, batalla.gd lo usa directamente
## sin llamar a crear_equipo_salvaje() / crear_equipo_desde_entrenador().
var equipo_rival: Array[BasePokemon] = []
var ubicacion: String = ""
var puede_huir: bool = true
var permite_captura: bool = true
var comentario: String = ""
var clima: Singleton.ClimaBatalla = Singleton.ClimaBatalla.NINGUNO
var extras: Dictionary = {}

static func _nueva_instancia() -> DatosInicioBatalla:
	return load("res://escenas/batalla/datos_inicio_batalla.gd").new()

static func crear_salvaje(especie: String, nivel: int = 25, ubicacion_actual: String = "", tema: Singleton.TemaBatalla = Singleton.TemaBatalla.NO_TIENE) -> DatosInicioBatalla:
	var datos = _nueva_instancia()
	datos.tipo = Singleton.TipoBatalla.SALVAJE
	datos.pokemon_salvaje_nombre_interno = especie.strip_edges()
	datos.pokemon_salvaje_nivel = maxi(nivel, 1)
	datos.ubicacion = ubicacion_actual
	datos.tema_grafico = tema
	datos.tema_grafico_frente = BattleLaunchService.resolver_tema_grafico_frente(tema)
	datos.puede_huir = true
	datos.permite_captura = true
	return datos

## BATTLE_TYPE_FIRST_BATTLE (pokeruby CB2_StartFirstBattle): el salvaje del rescate
## de ABEDUL. No se puede huir ni capturar; ver `es_primer_combate()`.
static func crear_primer_combate(especie: String, nivel: int, ubicacion_actual: String = "", tema: Singleton.TemaBatalla = Singleton.TemaBatalla.NO_TIENE) -> DatosInicioBatalla:
	var datos := crear_salvaje(especie, nivel, ubicacion_actual, tema)
	datos.puede_huir = false
	datos.permite_captura = false
	datos.extras[EXTRA_PRIMER_COMBATE] = true
	return datos

func es_torre_batalla() -> bool:
	return bool(extras.get(EXTRA_TORRE_BATALLA, false))

func es_primer_combate() -> bool:
	return bool(extras.get(EXTRA_PRIMER_COMBATE, false))

## BATTLE_TYPE_WALLY_TUTORIAL (ScrSpecial_StartWallyTutorialBattle): BLASCO, con el
## ZIGZAGOON que le presta NORMAN, atrapa un RALTS macho de Nv. 5. El jugador solo
## mira: no se puede huir y la POKé BALL de BLASCO siempre atrapa. `equipo_jugador`
## lo pone el llamador (el equipo guardado no se toca); ver `es_tutorial_blasco()`.
static func crear_tutorial_blasco(ubicacion_actual: String = "", tema: Singleton.TemaBatalla = Singleton.TemaBatalla.NO_TIENE) -> DatosInicioBatalla:
	var datos := crear_salvaje("RALTS", 5, ubicacion_actual, tema)
	datos.puede_huir = false
	datos.permite_captura = true
	datos.extras[EXTRA_TUTORIAL_BLASCO] = true
	datos.extras[EXTRA_TEXTOS_AUTOMATICOS] = true
	return datos

func es_tutorial_blasco() -> bool:
	return bool(extras.get(EXTRA_TUTORIAL_BLASCO, false))

## Plan 20260912 (Alcance 1, tipo 4): encuentro salvaje con ruleset de zona
## salvaje. Las balls viven en una memoria temporal separada de la mochila.
static func crear_zona_salvaje(especie: String, nivel: int = 25, ubicacion_actual: String = "", balls_disponibles: int = 30, tema: Singleton.TemaBatalla = Singleton.TemaBatalla.NO_TIENE) -> DatosInicioBatalla:
	var datos := crear_salvaje(especie, nivel, ubicacion_actual, tema)
	datos.ruleset = Singleton.RulesetBatalla.ZONA_SALVAJE
	datos.extras["balls_zona"] = maxi(balls_disponibles, 0)
	return datos

## Cantidad de balls temporales de zona (solo ruleset ZONA_SALVAJE).
func obtener_balls_zona() -> int:
	return int(extras.get("balls_zona", 0))

static func crear_entrenador(entrenador_datos: DatosEntrenador, tema: Singleton.TemaBatalla, comentario_post_batalla: String = "") -> DatosInicioBatalla:
	var datos = _nueva_instancia()
	datos.tipo = Singleton.TipoBatalla.ENTRENADOR
	datos.tema_grafico = tema
	datos.tema_grafico_frente = BattleLaunchService.resolver_tema_grafico_frente(tema)
	datos.entrenador = entrenador_datos
	datos.puede_huir = false
	datos.permite_captura = false
	datos.comentario = comentario_post_batalla
	return datos

static func crear_entrenador_doble(entrenador_datos: DatosEntrenador, tema: Singleton.TemaBatalla, comentario_post_batalla: String = "") -> DatosInicioBatalla:
	var datos := crear_entrenador(entrenador_datos, tema, comentario_post_batalla)
	datos.formato = Singleton.FormatoBatalla.DOBLE
	return datos

static func desde_diccionario(datos: Dictionary) -> DatosInicioBatalla:
	var configuracion = _nueva_instancia()
	configuracion.tipo = int(datos.get("tipo", Singleton.TipoBatalla.SALVAJE_TEST))
	configuracion.formato = int(datos.get("formato", Singleton.FormatoBatalla.SIMPLE))
	configuracion.ruleset = int(datos.get("ruleset", Singleton.RulesetBatalla.NORMAL))
	configuracion.tema_grafico = int(datos.get("tema_grafico", Singleton.TemaBatalla.NO_TIENE))
	configuracion.tema_grafico_frente = int(datos.get("tema_grafico_frente", BattleLaunchService.resolver_tema_grafico_frente(configuracion.tema_grafico)))
	configuracion.escenario = str(datos.get("escenario", ""))
	configuracion.terreno = int(datos.get("terreno", TERRENO_NINGUNO))
	configuracion.ubicacion = str(datos.get("ubicacion", ""))
	configuracion.comentario = str(datos.get("comentario", ""))
	configuracion.puede_huir = bool(datos.get("puede_huir", configuracion.tipo != Singleton.TipoBatalla.ENTRENADOR))
	configuracion.permite_captura = bool(datos.get("permite_captura", configuracion.tipo == Singleton.TipoBatalla.SALVAJE))
	configuracion.clima = int(datos.get("clima", Singleton.ClimaBatalla.NINGUNO))

	var entrenador_datos: Variant = datos.get("entrenador", null)
	if entrenador_datos is DatosEntrenador:
		configuracion.entrenador = entrenador_datos

	var pokemon_salvaje_datos: Variant = datos.get("pokemon_salvaje", {})
	if pokemon_salvaje_datos is Dictionary:
		configuracion.pokemon_salvaje_nombre_interno = str(pokemon_salvaje_datos.get("nombre_interno", "")).strip_edges()
		configuracion.pokemon_salvaje_nivel = maxi(int(pokemon_salvaje_datos.get("nivel", 1)), 1)
		var snap: Variant = pokemon_salvaje_datos.get("snapshot", {})
		if snap is Dictionary:
			configuracion.pokemon_salvaje_snapshot = snap

	var equipo_desde_datos: Variant = datos.get("equipo_jugador", [])
	if equipo_desde_datos is Array:
		for pokemon in equipo_desde_datos:
			if pokemon is BasePokemon:
				configuracion.equipo_jugador.append(pokemon)

	var equipo_rival_datos: Variant = datos.get("equipo_rival", [])
	if equipo_rival_datos is Array:
		for pokemon in equipo_rival_datos:
			if pokemon is BasePokemon:
				configuracion.equipo_rival.append(pokemon)

	for clave in datos.keys():
		var clave_str := str(clave)
		if CLAVES_CONOCIDAS.has(clave_str):
			continue
		configuracion.extras[clave] = datos[clave]

	return configuracion

func obtener_pokemon_salvaje() -> Dictionary:
	if pokemon_salvaje_nombre_interno.is_empty():
		return {}
	var resultado := {
		"nombre_interno": pokemon_salvaje_nombre_interno,
		"nivel": pokemon_salvaje_nivel,
	}
	if not pokemon_salvaje_snapshot.is_empty():
		resultado["snapshot"] = pokemon_salvaje_snapshot
	return resultado

func obtener_errores_validacion() -> PackedStringArray:
	var errores := PackedStringArray()
	match tipo:
		Singleton.TipoBatalla.SALVAJE:
			if pokemon_salvaje_nombre_interno.is_empty():
				errores.append("Falta el nombre interno del Pokémon salvaje")
		Singleton.TipoBatalla.ENTRENADOR:
			if entrenador == null:
				errores.append("Faltan los datos del entrenador")
	if ruleset == Singleton.RulesetBatalla.SIN_EQUIPO:
		errores.append("SIN_EQUIPO se deriva del estado del equipo; no debe pedirse en los datos de inicio")
	if ruleset == Singleton.RulesetBatalla.ZONA_SALVAJE and tipo != Singleton.TipoBatalla.SALVAJE:
		errores.append("La zona salvaje solo aplica a encuentros SALVAJE")
	if formato == Singleton.FormatoBatalla.DOBLE and tipo != Singleton.TipoBatalla.ENTRENADOR:
		errores.append("El formato DOBLE del Alcance 3 solo aplica a encuentros ENTRENADOR")
	return errores

func a_diccionario() -> Dictionary:
	var datos: Dictionary = extras.duplicate(true)
	datos["tipo"] = tipo
	datos["formato"] = formato
	datos["ruleset"] = ruleset
	datos["tema_grafico"] = tema_grafico
	datos["tema_grafico_frente"] = tema_grafico_frente
	datos["escenario"] = escenario
	datos["terreno"] = terreno
	datos["ubicacion"] = ubicacion
	datos["puede_huir"] = puede_huir
	datos["permite_captura"] = permite_captura
	datos["comentario"] = comentario
	datos["clima"] = clima

	if entrenador != null:
		datos["entrenador"] = entrenador

	var pokemon_salvaje := obtener_pokemon_salvaje()
	if not pokemon_salvaje.is_empty():
		datos["pokemon_salvaje"] = pokemon_salvaje

	if not equipo_jugador.is_empty():
		var equipo_copiado: Array[BasePokemon] = []
		for pokemon in equipo_jugador:
			equipo_copiado.append(pokemon)
		datos["equipo_jugador"] = equipo_copiado

	if not equipo_rival.is_empty():
		var rival_copiado: Array[BasePokemon] = []
		for pokemon in equipo_rival:
			rival_copiado.append(pokemon)
		datos["equipo_rival"] = rival_copiado

	return datos
