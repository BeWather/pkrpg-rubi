@tool
class_name ConfiguracionDebugBatalla
extends Resource
## PILOTO (opcion B): Resource tipado que cruza la frontera editor -> juego.
## La ventana nativa del plugin lo crea y guarda; lanzador_debug_batalla.gd lo
## convierte a DatosInicioBatalla (desde_diccionario) dentro del proceso del juego.
##
## Los campos numericos son espejo de los enums de scripts/singleton.gd para no
## depender del autoload Singleton en el proceso del editor:
##   TipoBatalla:    0 SALVAJE_TEST, 1 SALVAJE, 2 ENTRENADOR
##   FormatoBatalla: 0 SIMPLE, 1 DOBLE
##   RulesetBatalla: 0 NORMAL, 1 ZONA_SALVAJE

const TIPO_SALVAJE := 1
const TIPO_ENTRENADOR := 2

const SingletonScript := preload("res://scripts/singleton.gd")

## Registro completo del JSON de entrenadores (para reconstruir DatosEntrenador).
@export var entrenador_datos: Dictionary = {}

## Valores espejo de Singleton.TipoBatalla.
@export_range(0, 2) var tipo: int = TIPO_SALVAJE
## Valores espejo de Singleton.FormatoBatalla.
@export_range(0, 1) var formato: int = 0
## Valores espejo de Singleton.RulesetBatalla.
@export_range(0, 1) var ruleset: int = 0

## Id del escenario de batalla (EscenarioBatalla.ids_escenarios(): fondo, suelo
## y tira de entrada como en Rubí). Vacío = configuración antigua: batalla.gd usa
## entonces `tema_grafico` / `tema_grafico_frente`.
@export var escenario: String = ""
## gBattleTerrain para la animación de la tira de entrada: valores de
## EscenarioBatalla.Terreno (0 HIERBA_ALTA ... 9 LLANURA). -1 = automático
## (batalla.gd lo deduce del escenario o del tema legado).
@export_range(-1, 9) var terreno: int = -1

## LEGADO (configuraciones guardadas antes de `escenario`): tema grafico de
## fondo/suelo, valores de Singleton.TemaBatalla (0 NO_TIENE ... 22 ESTADIO_8).
## Solo se usa si `escenario` está vacío.
@export_range(0, 22) var tema_grafico: int = 1
## LEGADO: tema grafico del frente (entrada), valores de
## Singleton.TemaBatallaFrente. -1 = automatico (se deduce del tema principal).
@export_range(-1, 9) var tema_grafico_frente: int = -1
## Clave de tema musical de temas_musicales.json. Vacia = automatica
## (entrenador: su musica_id del JSON; salvaje: BATALLA_SALVAJE_1).
@export var musica_id: String = ""

## Origen del equipo activo: 0 = PARTIDA (copia editable en memoria),
## 1 = PRUEBA (equipo adicional propio de la memoria de prueba).
@export_enum("Partida", "Prueba") var origen_equipo: int = 0

## Copia editable en memoria del equipo leido de la partida. NUNCA se escribe
## de vuelta al JSON de la partida.
@export var equipo_partida_memoria: Array[Dictionary] = []

## Equipo adicional de prueba (memoria de prueba; viaja en este Resource).
@export var equipo_prueba: Array[Dictionary] = []

@export var especie_salvaje: String = "WURMPLE"
@export_range(1, 100) var nivel_salvaje: int = 5
@export var ubicacion: String = "RUTA_101"

## Snapshot completo del salvaje elegido en el slot (puede no estar guardado
## en la BBDD). Por ahora el boot solo usa nombre_interno y nivel; el resto
## queda listo para cuando BasePokemon acepte instancias completas.
@export var salvaje_datos: Dictionary = {}

## Nombre y sexo ("M"/"F") del jugador SOLO para la prueba; vacios = usar los
## de la partida. Nunca se escriben de vuelta al JSON de la partida.
@export var jugador_nombre: String = ""
@export var jugador_sexo: String = ""

## Opciones de batalla de la partida editadas SOLO para la prueba (claves:
## velocidad_texto, imagen_tipo, tipo_combate, animacion_combate, nivel_audio,
## controles). Vacio = usar las de la partida. Nunca se escriben al JSON.
@export var opciones: Dictionary = {}

## Clima impuesto al iniciar la batalla: 0 NINGUNO, 1 SOLEADO, 2 LLUVIA,
## 3 TORMENTA_ARENA, 4 GRANIZO. Pendiente de implementar en el sistema de
## batalla; por ahora solo viaja en el Resource y en el diccionario de inicio.
@export_range(0, 4) var clima: int = 0

@export var entrenador_nombre: String = ""
@export var entrenador_clase: String = ""

@export var puede_huir: bool = true
@export var permite_captura: bool = true
@export var comentario: String = ""


func es_salvaje() -> bool:
	return tipo == TIPO_SALVAJE


func es_entrenador() -> bool:
	return tipo == TIPO_ENTRENADOR


## Diccionario de entrada para DatosInicioBatalla.desde_diccionario().
## El entrenador se agrega aparte (boot) porque exige una instancia DatosEntrenador.
func a_diccionario_inicio() -> Dictionary:
	var datos: Dictionary = {
		"tipo": tipo,
		"formato": formato,
		"ruleset": ruleset,
		"tema_grafico": tema_grafico,
		"tema_grafico_frente": tema_frente_efectivo(),
		"escenario": escenario,
		"terreno": terreno,
		"ubicacion": ubicacion,
		"puede_huir": puede_huir,
		"permite_captura": permite_captura,
		"comentario": comentario,
		"clima": clima,
	}
	if es_salvaje():
		var salvaje: Dictionary = {
			"nombre_interno": especie_salvaje.strip_edges().to_upper(),
			"nivel": nivel_salvaje,
		}
		if not salvaje_datos.is_empty():
			salvaje["snapshot"] = salvaje_datos
		datos["pokemon_salvaje"] = salvaje
	return datos


## Tema frente efectivo: si el usuario eligio AUTOMATICO (-1), delega en
## BattleLaunchService.resolver_tema_grafico_frente() (Etapa 4, SDD
## 2026-09-15-battle-launch-service) — antes una réplica manual del match de
## batalla.gd::_resolver_tema_grafico_frente() (ya movido a BattleLaunchService).
func tema_frente_efectivo() -> int:
	if tema_grafico_frente >= 0:
		return tema_grafico_frente
	return BattleLaunchService.resolver_tema_grafico_frente(tema_grafico)


## Resumen legible para labels y logs.
func resumen() -> String:
	var texto_tipo := "SALVAJE" if es_salvaje() else "ENTRENADOR"
	var texto_formato := "DOBLE" if formato == 1 else "SIMPLE"
	var texto_ruleset := "ZONA_SALVAJE" if ruleset == 1 else "NORMAL"
	var texto_rival := "%s Nv.%d (%s)" % [especie_salvaje, nivel_salvaje, ubicacion]
	if es_entrenador():
		texto_rival = "%s %s" % [entrenador_clase, entrenador_nombre]
	var nombre_terreno := "AUTO" if terreno < 0 else str(EscenarioBatalla.Terreno.find_key(terreno))
	if escenario.is_empty():
		var nombre_tema := str(SingletonScript.TemaBatalla.find_key(tema_grafico))
		var nombre_frente := "AUTO" if tema_grafico_frente < 0 else str(SingletonScript.TemaBatallaFrente.find_key(tema_grafico_frente))
		return "%s / %s / %s | Rival: %s | Tema (legado): %s / Frente: %s / Terreno: %s" % [
			texto_tipo, texto_formato, texto_ruleset, texto_rival, nombre_tema, nombre_frente, nombre_terreno,
		]
	return "%s / %s / %s | Rival: %s | Escenario: %s / Terreno: %s" % [
		texto_tipo, texto_formato, texto_ruleset, texto_rival, escenario, nombre_terreno,
	]


## Escenario equivalente a un tema gráfico legado, para migrar configuraciones
## guardadas antes de `escenario` (la ventana lo usa al restaurarlas).
static func escenario_desde_tema(tema: int) -> String:
	if tema == SingletonScript.TemaBatalla.CUEVA_GROUDON:
		return EscenarioBatalla.ID_GROUDON
	return EscenarioBatalla.id_terreno(BattleLaunchService.terreno_desde_tema(tema))
