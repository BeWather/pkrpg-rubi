class_name EvolucionPokemon
extends RefCounted

## Lógica de evolución de pokeruby: `GetEvolutionTargetSpecies` (`src/pokemon_3.c`),
## el cambio de especie de `Task_EvolutionScene` (`src/evolution_scene.c`) y
## `CreateShedinja`. Sin interfaz: la escena es `EscenaEvolucion`.

## Tipo de comprobación (`type` de GetEvolutionTargetSpecies).
enum Modo {
	NIVEL = 0,             ## Al subir de nivel (combate, CARAMELORARO).
	INTERCAMBIO = 1,       ## Al recibirlo en un intercambio.
	OBJETO = 2,            ## Al usar un objeto (piedra evolutiva) sobre él.
	OBJETO_CONSULTA = 3,   ## Solo consultar si un objeto lo haría evolucionar.
}

## Amistad mínima de EVO_FRIENDSHIP, EVO_FRIENDSHIP_DAY y EVO_FRIENDSHIP_NIGHT.
const AMISTAD_EVOLUCION: int = 220
## HOLD_EFFECT_PREVENT_EVOLVE (PIEDRA ETERNA): bloquea los modos 0-2.
const OBJETO_PIEDRA_ETERNA: String = "PIEDRAETERNA"
## WURMPLE: (personalidad >> 16) % 10 <= 4 da SILCOON; si no, CASCOON.
const CORTE_SILCOON: int = 4
## Contador de GAME_STAT_EVOLVED_POKEMON (SistemaGuardado.datos_persistentes).
const CONTADOR_EVOLUCIONADOS: String = "pokemon_evolucionados"
const ESPECIE_SHEDINJA: String = "SHEDINJA"
const TAMANO_EQUIPO: int = 6


## `GetEvolutionTargetSpecies`: especie en la que evolucionaría `pokemon`, o ""
## si no evoluciona. `objeto` es el `nombre_interno` del objeto usado (modos
## OBJETO y OBJETO_CONSULTA). `hora` (-1 = RelojJuego) decide día/noche.
##
## Como en el decomp, se recorren todas las ranuras y gana la última que se
## cumple (salvo en los modos de objeto, que paran en la primera), y en
## INTERCAMBIO con EVO_TRADE_ITEM el objeto llevado se consume.
static func especie_destino(pokemon: BasePokemon, modo: Modo, objeto: String = "", hora: int = -1) -> String:
	if pokemon == null or pokemon.huevo:
		return ""
	if pokemon.objeto == OBJETO_PIEDRA_ETERNA and modo != Modo.OBJETO_CONSULTA:
		return ""
	var evoluciones := DatosEvolucion.evoluciones(pokemon.nombre_interno)
	var destino := ""
	match modo:
		Modo.NIVEL:
			for evo: Dictionary in evoluciones:
				if _cumple_por_nivel(pokemon, evo, hora):
					destino = str(evo["destino"])
		Modo.INTERCAMBIO:
			# TODO: no hay sistema de intercambio; nadie llama a este modo todavía.
			for evo: Dictionary in evoluciones:
				match str(evo["metodo"]):
					DatosEvolucion.EVO_TRADE:
						destino = str(evo["destino"])
					DatosEvolucion.EVO_TRADE_ITEM:
						if str(evo["parametro"]) == pokemon.objeto:
							pokemon.objeto = ""
							destino = str(evo["destino"])
		Modo.OBJETO, Modo.OBJETO_CONSULTA:
			for evo: Dictionary in evoluciones:
				if str(evo["metodo"]) == DatosEvolucion.EVO_ITEM and str(evo["parametro"]) == objeto:
					destino = str(evo["destino"])
					break
	return destino


## true si `objeto` (nombre_interno) haría evolucionar a `pokemon` (modo 3).
static func objeto_hace_evolucionar(pokemon: BasePokemon, objeto: String) -> bool:
	return not especie_destino(pokemon, Modo.OBJETO_CONSULTA, objeto).is_empty()


static func _cumple_por_nivel(pokemon: BasePokemon, evo: Dictionary, hora: int) -> bool:
	var metodo := str(evo["metodo"])
	var parametro := int(evo["parametro"]) if not (evo["parametro"] is String) else 0
	match metodo:
		DatosEvolucion.EVO_FRIENDSHIP:
			return pokemon.felicidad >= AMISTAD_EVOLUCION
		DatosEvolucion.EVO_FRIENDSHIP_DAY:
			return RelojJuego.es_de_dia(hora) and pokemon.felicidad >= AMISTAD_EVOLUCION
		DatosEvolucion.EVO_FRIENDSHIP_NIGHT:
			return RelojJuego.es_de_noche(hora) and pokemon.felicidad >= AMISTAD_EVOLUCION
		DatosEvolucion.EVO_LEVEL, DatosEvolucion.EVO_LEVEL_NINJASK:
			return parametro <= pokemon.nivel
		DatosEvolucion.EVO_LEVEL_ATK_GT_DEF:
			return parametro <= pokemon.nivel and pokemon.estad_ataque > pokemon.estad_defensa
		DatosEvolucion.EVO_LEVEL_ATK_EQ_DEF:
			return parametro <= pokemon.nivel and pokemon.estad_ataque == pokemon.estad_defensa
		DatosEvolucion.EVO_LEVEL_ATK_LT_DEF:
			return parametro <= pokemon.nivel and pokemon.estad_ataque < pokemon.estad_defensa
		DatosEvolucion.EVO_LEVEL_SILCOON:
			return parametro <= pokemon.nivel and _valor_wurmple(pokemon) <= CORTE_SILCOON
		DatosEvolucion.EVO_LEVEL_CASCOON:
			return parametro <= pokemon.nivel and _valor_wurmple(pokemon) > CORTE_SILCOON
		DatosEvolucion.EVO_BEAUTY:
			# TODO: concursos y POKéCUBOS no implementados; `belleza` no sube aún.
			return parametro <= pokemon.belleza
	# EVO_LEVEL_SHEDINJA no evoluciona por sí mismo: SHEDINJA lo crea
	# `crear_shedinja` al evolucionar NINCADA en NINJASK.
	return false


static func _valor_wurmple(pokemon: BasePokemon) -> int:
	return ((pokemon.personalidad >> 16) & 0xFFFF) % 10


## Cambia la especie de `pokemon` a `destino` como el estado 13 de
## `Task_EvolutionScene`: SetMonData(SPECIES) + CalculateMonStats +
## EvolutionRenameMon. No toca la Pokédex (ver `registrar_evolucion`).
## Devuelve false si `destino` no existe en la BD.
static func evolucionar(pokemon: BasePokemon, destino: String) -> bool:
	if pokemon == null or destino.is_empty():
		return false
	var fila_nueva := DatabaseManager.obtener_datos_pokemon(destino)
	if fila_nueva.is_empty():
		push_warning("[EvolucionPokemon] Especie '%s' no encontrada" % destino)
		return false
	var fila_vieja := DatabaseManager.obtener_datos_pokemon(pokemon.nombre_interno)
	var nombre_viejo := str(fila_vieja.get("nombre", pokemon.nombre))
	var segunda_habilidad := _usa_segunda_habilidad(pokemon, fila_vieja)

	pokemon.nombre_interno = destino
	pokemon.nombre = str(fila_nueva.get("nombre", destino))
	pokemon.numero_nacional = int(fila_nueva.get("numero_nacional", pokemon.numero_nacional))
	pokemon.tipo_1_id = int(fila_nueva.get("tipo_1_id", 0))
	pokemon.tipo_1 = DatabaseManager.obtener_nombre_tipo_por_id(pokemon.tipo_1_id)
	if fila_nueva.get("tipo_2_id") != null:
		pokemon.tipo_2_id = int(fila_nueva["tipo_2_id"])
		pokemon.tipo_2 = DatabaseManager.obtener_nombre_tipo_por_id(pokemon.tipo_2_id)
	else:
		pokemon.tipo_2_id = 0
		pokemon.tipo_2 = ""
	pokemon.habilidad = _habilidad_por_ranura(fila_nueva, segunda_habilidad, pokemon.habilidad)
	recalcular_estadisticas(pokemon, fila_nueva)
	# EvolutionRenameMon: el mote que era el nombre de la especie pasa a ser el
	# nombre nuevo (aquí, mote vacío = nombre de la especie).
	if pokemon.mote == nombre_viejo:
		pokemon.mote = ""
	return true


## `CalculateMonStats` tras un cambio de especie: estadísticas con los IV/EV
## actuales y los PS actuales sumando la diferencia del máximo (mínimo 1 si no
## estaba debilitado). SHEDINJA tiene siempre 1 PS máximo.
static func recalcular_estadisticas(pokemon: BasePokemon, fila: Dictionary = {}) -> void:
	var datos := fila if not fila.is_empty() else DatabaseManager.obtener_datos_pokemon(pokemon.nombre_interno)
	if datos.is_empty():
		return
	var ps_max_antes := pokemon.estad_ps
	var ps_antes := pokemon.estad_ps_actual
	# Deja los PS actuales al máximo; se corrigen debajo.
	pokemon._recalcular_stats_con_ivs_actuales()
	if pokemon.nombre_interno == ESPECIE_SHEDINJA:
		pokemon.estad_ps = 1
		pokemon.estad_ps_actual = 1 if ps_antes != 0 or ps_max_antes == 0 else 0
	elif ps_antes == 0 and ps_max_antes == 0:
		pokemon.estad_ps_actual = pokemon.estad_ps
	elif ps_antes != 0:
		pokemon.estad_ps_actual = clampi(ps_antes + pokemon.estad_ps - ps_max_antes, 1, pokemon.estad_ps)
	else:
		pokemon.estad_ps_actual = 0
	var ratio := str(datos.get("ratio_crecimiento", ""))
	pokemon.exp_sig_nivel = pokemon.get_exp_nivel(pokemon.nivel + 1, ratio)
	pokemon.calcular_porcentaje_experiencia()


## Pokédex vista + atrapada de la especie nueva y GAME_STAT_EVOLVED_POKEMON.
static func registrar_evolucion(destino: String) -> void:
	SistemaGuardado.registrar_pokemon_visto(destino)
	SistemaGuardado.registrar_pokemon_atrapado(destino)
	SistemaGuardado.incrementar_contador(CONTADOR_EVOLUCIONADOS)


## `CreateShedinja`: si `especie_previa` evoluciona con EVO_LEVEL_NINJASK y el
## equipo tiene hueco, añade al final una copia de `evolucionado` como la
## especie de la ranura 1 (SHEDINJA), sin objeto, marcas, cintas ni estado, y
## la registra en la Pokédex. En Rubí no gasta ninguna POKé BALL.
## Devuelve el Pokémon creado o null.
static func crear_shedinja(especie_previa: String, evolucionado: BasePokemon, equipo: Array) -> BasePokemon:
	var evoluciones := DatosEvolucion.evoluciones(especie_previa)
	if evoluciones.size() < 2 or str(evoluciones[0]["metodo"]) != DatosEvolucion.EVO_LEVEL_NINJASK:
		return null
	if evolucionado == null or equipo.size() >= TAMANO_EQUIPO:
		return null
	var especie := str(evoluciones[1]["destino"])
	var copia := evolucionado.duplicate()
	if not evolucionar(copia, especie):
		return null
	copia.mote = ""
	copia.objeto = ""
	copia.marcas = {"circulo": false, "cuadrado": false, "triangulo": false, "corazon": false}
	copia.cintas = []
	copia.estado = Singleton.ProblemaEstado.NORMAL
	copia.indice_orden_original = -1
	equipo.append(copia)
	SistemaGuardado.registrar_pokemon_visto(especie)
	SistemaGuardado.registrar_pokemon_atrapado(especie)
	return copia


## true si `pokemon` tiene la segunda habilidad de su especie actual
## (MON_DATA_ALT_ABILITY).
static func _usa_segunda_habilidad(pokemon: BasePokemon, fila: Dictionary) -> bool:
	var segunda: Variant = fila.get("habilidad_2")
	if segunda == null or str(segunda).is_empty():
		return false
	return BasePokemon.normalizar_habilidad(str(segunda)) == pokemon.habilidad \
		and BasePokemon.normalizar_habilidad(str(fila.get("habilidad_1", ""))) != pokemon.habilidad


## `GetAbilityBySpecies`: la segunda habilidad si la ranura lo pide y existe;
## si no, la primera.
static func _habilidad_por_ranura(fila: Dictionary, segunda: bool, actual: String) -> String:
	var clave := "habilidad_2" if segunda else "habilidad_1"
	var valor: Variant = fila.get(clave)
	if valor == null or str(valor).is_empty():
		valor = fila.get("habilidad_1")
	if valor == null or str(valor).is_empty():
		return actual
	return BasePokemon.normalizar_habilidad(str(valor))
