class_name HabilidadesCombate
extends RefCounted

## Lógica central de las habilidades en combate (Gen 3, pokeruby
## `AbilityBattleEffects` y los chequeos sueltos de battle_script_commands.c,
## calculate_base_damage.c y battle_main.c). Todo son funciones estáticas y
## puras: reciben los Pokémon, el `CampoCombate` y (si hace falta) un
## `sortear: Callable(n) -> int` para tests deterministas. Mutan el estado
## lógico (modificadores, estado, tipos, habilidad temporal) y devuelven
## `AccionHabilidad` para que la escena las presente.
##
## La habilidad de un Pokémon es el `nombre_interno` de la tabla Habilidades
## (BasePokemon.habilidad). Los textos son los de la ROM española
## (src/data/battle_strings_en.h del decomp ES) y llevan el nombre de la
## habilidad leído de la BD.
##
## El estado de cada habilidad (qué motor la llama) se lista en
## `RegistroHabilidades`.

# ─── Claves (Habilidades.nombre_interno) ─────────────────────────────────────
const HEDOR := "HEDOR"
const LLOVIZNA := "LLOVIZNA"
const IMPULSO := "IMPULSO"
const ARMADURABATALLA := "ARMADURABATALLA"
const ROBUSTEZ := "ROBUSTEZ"
const HUMEDAD := "HUMEDAD"
const FLEXIBILIDAD := "FLEXIBILIDAD"
const VELOARENA := "VELOARENA"
const ELECESTATICA := "ELECESTATICA"
const ABSORBEELEC := "ABSORBEELEC"
const ABSORBEAGUA := "ABSORBEAGUA"
const DESPISTE := "DESPISTE"
const ACLIMATACION := "ACLIMATACION"
const OJOCOMPUESTO := "OJOCOMPUESTO"
const INSOMNIO := "INSOMNIO"
const CAMBIOCOLOR := "CAMBIOCOLOR"
const INMUNIDAD := "INMUNIDAD"
const ABSORBEFUEGO := "ABSORBEFUEGO"
const POLVOESCUDO := "POLVOESCUDO"
const RITMOPROPIO := "RITMOPROPIO"
const VENTOSAS := "VENTOSAS"
const INTIMIDACION := "INTIMIDACION"
const SOMBRATRAMPA := "SOMBRATRAMPA"
const PIELTOSCA := "PIELTOSCA"
const SUPERGUARDA := "SUPERGUARDA"
const LEVITACION := "LEVITACION"
const EFECTOESPORA := "EFECTOESPORA"
const SINCRONIA := "SINCRONIA"
const CUERPOPURO := "CUERPOPURO"
const CURANATURAL := "CURANATURAL"
const PARARRAYOS := "PARARRAYOS"
const DICHA := "DICHA"
const NADORAPIDO := "NADORAPIDO"
const CLOROFILA := "CLOROFILA"
const ILUMINACION := "ILUMINACION"
const RASTRO := "RASTRO"
const POTENCIA := "POTENCIA"
const PUNTOTOXICO := "PUNTOTOXICO"
const FOCOINTERNO := "FOCOINTERNO"
const ESCUDOMAGMA := "ESCUDOMAGMA"
const VELOAGUA := "VELOAGUA"
const IMAN := "IMAN"
const INSONORIZAR := "INSONORIZAR"
const CURALLUVIA := "CURALLUVIA"
const CHORROARENA := "CHORROARENA"
const PRESION := "PRESION"
const SEBO := "SEBO"
const MADRUGAR := "MADRUGAR"
const CUERPOLLAMA := "CUERPOLLAMA"
const FUGA := "FUGA"
const VISTALINCE := "VISTALINCE"
const CORTEFUERTE := "CORTEFUERTE"
const RECOGIDA := "RECOGIDA"
const AUSENTE := "AUSENTE"
const ENTUSIASMO := "ENTUSIASMO"
const GRANENCANTO := "GRANENCANTO"
const MAS := "MAS"
const MENOS := "MENOS"
const PREDICCION := "PREDICCION"
const VISCOSIDAD := "VISCOSIDAD"
const MUDAR := "MUDAR"
const AGALLAS := "AGALLAS"
const ESCAMAESPECIAL := "ESCAMAESPECIAL"
const LODOLIQUIDO := "LODOLIQUIDO"
const ESPESURA := "ESPESURA"
const MARLLAMAS := "MARLLAMAS"
const TORRENTE := "TORRENTE"
const ENJAMBRE := "ENJAMBRE"
const CABEZAROCA := "CABEZAROCA"
const SEQUIA := "SEQUIA"
const TRAMPAARENA := "TRAMPAARENA"
const ESPIRITUVITAL := "ESPIRITUVITAL"
const HUMOBLANCO := "HUMOBLANCO"
const ENERGIAPURA := "ENERGIAPURA"
const CAPARAZON := "CAPARAZON"
const CACOFONIA := "CACOFONIA"
const BUCLEAIRE := "BUCLEAIRE"

## Habilidades de apuro (PS <= 1/3): tipo cuya potencia suben ×1.5.
const HABILIDADES_APURO := {
	"ESPESURA": "PLANTA",
	"MARLLAMAS": "FUEGO",
	"TORRENTE": "AGUA",
	"ENJAMBRE": "BICHO",
}

## Estados permanentes que cada habilidad impide / cura (INMUNIDAD, etc.).
## Valores: Singleton.ProblemaEstado como enteros (ENVENENADO 1, CONGELADO 2,
## QUEMADO 3, PARALIZADO 4, DORMIDO 5).
const ESTADO_ENVENENADO := 1
const ESTADO_CONGELADO := 2
const ESTADO_QUEMADO := 3
const ESTADO_PARALIZADO := 4
const ESTADO_DORMIDO := 5

const HABILIDAD_CONTRA_ESTADO := {
	"INMUNIDAD": [1],
	"FLEXIBILIDAD": [4],
	"INSOMNIO": [5],
	"ESPIRITUVITAL": [5],
	"VELOAGUA": [3],
	"ESCUDOMAGMA": [2],
}

const NOMBRES_ESTADO := {
	1: "ENVENENAMIENTO",
	2: "CONGELACIÓN",
	3: "QUEMADURA",
	4: "PARÁLISIS",
	5: "SUEÑO",
}

static var _cache_nombres: Dictionary = {}


# ─── Identificación ──────────────────────────────────────────────────────────

## Habilidad efectiva: la prestada por RASTRO si la hay; "" si no hay Pokémon,
## es un huevo o no tiene habilidad.
static func de(pokemon: BasePokemon) -> String:
	if pokemon == null or pokemon.huevo:
		return ""
	var temporal := pokemon.habilidad_temporal.strip_edges().to_upper()
	var clave := temporal if not temporal.is_empty() else pokemon.habilidad.strip_edges().to_upper()
	clave=str(BattleTransformRules.data(pokemon).get("ability",clave)).strip_edges().to_upper()
	return "" if clave == "SIN_HABILIDAD" else clave


## Set an effective combat ability through existing Trace/Transform authority.
## Explicit no-ability must not fall through to the persistent party ability.
static func establecer_habilidad_combate(pokemon: BasePokemon, ability: String) -> void:
	var value: String=ability.strip_edges().to_upper()
	if value.is_empty():value="SIN_HABILIDAD"
	var transformed: Dictionary=BattleTransformRules.data(pokemon)
	if not transformed.is_empty():transformed.ability=value
	else:pokemon.habilidad_temporal=value

## Ruby atkDA: same nonzero abilities are allowed; no entry hooks are fired.
static func intercambiar_habilidades_combate(actor: BasePokemon, target: BasePokemon) -> bool:
	if actor==null or target==null or actor==target:return false
	var before_actor: String=de(actor);var before_target: String=de(target)
	if (before_actor.is_empty() and before_target.is_empty()) or before_actor==SUPERGUARDA or before_target==SUPERGUARDA:return false
	establecer_habilidad_combate(actor,before_target)
	establecer_habilidad_combate(target,before_actor)
	return true

static func tiene(pokemon: BasePokemon, clave: String) -> bool:
	return de(pokemon) == clave


## Nombre mostrable de la habilidad (Habilidades.nombre, "CUERPO PURO").
static func nombre(clave: String) -> String:
	if _cache_nombres.has(clave):
		return _cache_nombres[clave]
	var visible := clave
	if DatabaseManager != null and DatabaseManager.esta_conectado():
		var datos: Dictionary = DatabaseManager.obtener_datos_habilidad(clave)
		visible = str(datos.get("nombre", clave)).strip_edges()
		if visible.is_empty():
			visible = clave
	_cache_nombres[clave] = visible
	return visible


## Quita lo que una habilidad cambió solo para el combate: habilidad prestada
## (RASTRO) y tipos (CAMBIO COLOR). Se llama al salir del campo y al acabar.
static func limpiar_combate(pokemon: BasePokemon) -> void:
	if pokemon == null:
		return
	pokemon.habilidad_temporal = ""
	if not pokemon.tipos_originales_combate.is_empty():
		pokemon.tipo_1 = pokemon.tipos_originales_combate[0]
		pokemon.tipo_2 = pokemon.tipos_originales_combate[1]
		pokemon.tipos_originales_combate = []


static func _con_estado(pokemon: BasePokemon) -> bool:
	var e: int = pokemon.estado
	return e != Singleton.ProblemaEstado.NORMAL and e != Singleton.ProblemaEstado.DEBILITADO \
			and e != Singleton.ProblemaEstado.POKERUS


static func _n(pokemon: BasePokemon) -> String:
	return pokemon.get_nombre_combate()


static func _sortear(n: int, sortear: Callable) -> int:
	if sortear.is_valid():
		return int(sortear.call(n))
	return randi() % n


# ─── Entrada al campo ────────────────────────────────────────────────────────

## Clima que provoca la habilidad al entrar (Singleton.ClimaBatalla), 0 si ninguno.
static func clima_de_entrada(clave: String) -> int:
	match clave:
		LLOVIZNA:
			return Singleton.ClimaBatalla.LLUVIA
		SEQUIA:
			return Singleton.ClimaBatalla.SOLEADO
		CHORROARENA:
			return Singleton.ClimaBatalla.TORMENTA_ARENA
	return Singleton.ClimaBatalla.NINGUNO


## ABILITYEFFECT_ON_SWITCHIN: clima de LLOVIZNA / SEQUÍA / CHORRO ARENA,
## INTIMIDACIÓN y RASTRO. `combatiente_de`: Callable(BasePokemon) ->
## PokemonEnCombate. `durante_combate`: true si entra por un cambio (AUSENTE
## empieza holgazaneando, truantCounter = 1) y false al inicio de la batalla.
## omitir_diferidas: INTIMIDACIÓN y RASTRO solo se marcan en atk52 (STATUS3_INTIMIDATE_POKES,
## STATUS3_TRACE); tras un relevo los resuelve HandleFaintedMonActions con `al_entrar_diferidas`.
static func al_entrar(pokemon: BasePokemon, campo: CampoCombate, combatiente_de: Callable, sortear: Callable = Callable(), durante_combate: bool = false, es_reentrada: bool = false, omitir_diferidas: bool = false) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if pokemon == null or pokemon.estad_ps_actual <= 0:
		return acciones
	var clave := de(pokemon)
	var propio: PokemonEnCombate = combatiente_de.call(pokemon) if combatiente_de.is_valid() else null

	if clave == AUSENTE and durante_combate and propio != null:
		propio.holgazaneando = true

	var clima_nuevo := clima_de_entrada(clave)
	if clima_nuevo != Singleton.ClimaBatalla.NINGUNO and campo.clima != clima_nuevo:
		campo.clima = clima_nuevo
		var texto := ""
		match clave:
			LLOVIZNA:
				texto = "¡%s de %s\nhizo llover!" % [nombre(clave), _n(pokemon)]
			SEQUIA:
				texto = "¡%s de %s\nintensifica los rayos del sol!" % [nombre(clave), _n(pokemon)]
			CHORROARENA:
				texto = "¡%s de %s\nlevanta una tormenta de arena!" % [nombre(clave), _n(pokemon)]
		acciones.append(AccionHabilidad.clima(clima_nuevo, texto))

	if not omitir_diferidas:
		acciones.append_array(al_entrar_diferidas(pokemon, campo, combatiente_de, sortear, durante_combate, es_reentrada))
	# PREDICCIÓN: el clima recién puesto (o el ya existente) cambia el tipo de CASTFORM.
	if not es_reentrada:
		for en_campo in campo.todos():
			acciones.append_array(actualizar_prediccion(en_campo, campo))
	return acciones


## INTIMIDACIÓN y RASTRO de `pokemon` (ABILITYEFFECT_INTIMIDATE1 / ABILITYEFFECT_TRACE).
static func al_entrar_diferidas(pokemon: BasePokemon, campo: CampoCombate, combatiente_de: Callable, sortear: Callable = Callable(), durante_combate: bool = false, es_reentrada: bool = false) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if pokemon == null or pokemon.estad_ps_actual <= 0:
		return acciones
	var clave := de(pokemon)
	if clave == INTIMIDACION:
		for rival in campo.rivales_de(pokemon):
			acciones.append_array(_intimidar(pokemon, rival, combatiente_de))

	if clave == RASTRO and not es_reentrada:
		var candidatos: Array[BasePokemon] = []
		for rival in campo.rivales_de(pokemon):
			if not de(rival).is_empty():
				candidatos.append(rival)
		if not candidatos.is_empty():
			var elegido: BasePokemon = candidatos[_sortear(candidatos.size(), sortear)]
			pokemon.habilidad_temporal = de(elegido)
			acciones.append(AccionHabilidad.mensaje("¡%s RASTREÓ\n%s de %s!" % [_n(pokemon), nombre(de(elegido)), _n(elegido)]))
			# Switch-in effects se repiten: la habilidad copiada también entra.
			acciones.append_array(al_entrar(pokemon, campo, combatiente_de, sortear, durante_combate, true))
	return acciones


## PREDICCIÓN (CASTFORM): su tipo y su forma siguen al clima efectivo. El tipo se
## restaura al salir del campo (`limpiar_combate`); la forma solo existe en el sprite.
static func actualizar_prediccion(pokemon: BasePokemon, campo: CampoCombate) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if pokemon == null or pokemon.estad_ps_actual <= 0 or not tiene(pokemon, PREDICCION):
		return acciones
	if str(BattleTransformRules.data(pokemon).get("species",pokemon.nombre_interno)) != "CASTFORM":
		return acciones
	var tipo := tipo_por_prediccion(campo.clima_efectivo())
	var tipos: Array[String] = BattleTransformRules.types(pokemon)
	if tipos[0] == tipo and tipos[1].is_empty():
		return acciones
	if not BattleTransformRules.set_types(pokemon,tipo,""):
		if pokemon.tipos_originales_combate.is_empty():
			pokemon.tipos_originales_combate = [pokemon.tipo_1, pokemon.tipo_2]
		pokemon.tipo_1 = tipo
		pokemon.tipo_2 = ""
	acciones.append(AccionHabilidad.cambio_forma(pokemon, forma_por_prediccion(tipo), "¡%s cambió\nde forma!" % _n(pokemon)))
	return acciones


static func _intimidar(origen: BasePokemon, rival: BasePokemon, combatiente_de: Callable) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	var protector := impide_bajar_estadistica(rival, "ataque")
	if not protector.is_empty():
		acciones.append(AccionHabilidad.mensaje("¡%s de %s\nevita perder ATAQUE!" % [nombre(protector), _n(rival)]))
		return acciones
	var combatiente: PokemonEnCombate = combatiente_de.call(rival) if combatiente_de.is_valid() else null
	if combatiente == null:
		return acciones
	if preload("res://scripts/battle/mist_rules.gd").blocks(combatiente):
		acciones.append(AccionHabilidad.mensaje("¡La neblina protegió a %s!"%_n(rival)));return acciones
	if combatiente.mod_ataque <= -6:
		acciones.append(AccionHabilidad.mensaje("¡Las estadísticas de %s\nno bajarán más!" % _n(rival)))
		return acciones
	combatiente.cambiar_modificador("ataque", -1)
	acciones.append(AccionHabilidad.estadistica(rival, false,
			"¡%s de %s\nreduce el ATAQUE de %s!" % [nombre(INTIMIDACION), _n(origen), _n(rival)],"ataque",-1))
	return acciones


## Protección de características: habilidad de `objetivo` que impide que un
## rival le baje `stat` ("ataque", "precision"...), o "".
static func impide_bajar_estadistica(objetivo: BasePokemon, stat: String) -> String:
	var clave := de(objetivo)
	if clave == CUERPOPURO or clave == HUMOBLANCO:
		return clave
	if clave == CORTEFUERTE and stat == "ataque":
		return clave
	if clave == VISTALINCE and stat == "precision":
		return clave
	return ""


# ─── Fin de turno ────────────────────────────────────────────────────────────

## ABILITYEFFECT_ENDTURN (+ ABILITYEFFECT_IMMUNITY): CURA LLUVIA, MUDAR,
## IMPULSO y el cambio de AUSENTE; las habilidades contra estados curan lo que
## tenga el Pokémon. No hace nada con un Pokémon debilitado.
static func fin_de_turno(pokemon: BasePokemon, campo: CampoCombate, combatiente: PokemonEnCombate, sortear: Callable = Callable()) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if pokemon == null or pokemon.estad_ps_actual <= 0:
		return acciones
	var clave := de(pokemon)
	acciones.append_array(actualizar_prediccion(pokemon, campo))
	match clave:
		CURALLUVIA:
			if campo.clima_efectivo() == Singleton.ClimaBatalla.LLUVIA and pokemon.estad_ps_actual < pokemon.estad_ps:
				var cura := maxi(1, pokemon.estad_ps / 16)
				acciones.append(AccionHabilidad.curar(pokemon, cura, "¡%s restauró PS\ncon %s!" % [_n(pokemon), nombre(clave)]))
		MUDAR:
			if _con_estado(pokemon) and _sortear(3, sortear) == 0:
				var estado_previo: int = pokemon.estado
				pokemon.estado = Singleton.ProblemaEstado.NORMAL
				acciones.append(AccionHabilidad.estado(pokemon, "¡%s de %s\ncura su problema de %s!" % [nombre(clave), _n(pokemon), str(NOMBRES_ESTADO.get(estado_previo, "estado"))]))
		IMPULSO:
			if combatiente != null and combatiente.rondas_en_campo >= 1 and combatiente.mod_velocidad < 6:
				combatiente.cambiar_modificador("velocidad", 1)
				acciones.append(AccionHabilidad.estadistica(pokemon, true, "¡%s de %s\nsubió su VELOCIDAD!" % [nombre(clave), _n(pokemon)],"velocidad",1))
		AUSENTE:
			if combatiente != null:
				combatiente.holgazaneando = not combatiente.holgazaneando
	acciones.append_array(curar_estado_por_habilidad(pokemon, combatiente))
	return acciones


## ABILITYEFFECT_IMMUNITY: si el Pokémon tiene un estado que su habilidad
## impide (p. ej. tras RASTRO), la habilidad lo cura. Con `combatiente`,
## RITMO PROPIO cura la confusión y DESPISTE el enamoramiento.
static func curar_estado_por_habilidad(pokemon: BasePokemon, combatiente: PokemonEnCombate = null) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	var clave := de(pokemon)
	if combatiente != null:
		if clave == RITMOPROPIO and combatiente.esta_confuso:
			combatiente.esta_confuso = false
			acciones.append(AccionHabilidad.mensaje("¡%s de %s\nlo sacó de la confusión!" % [nombre(clave), _n(pokemon)]))
		elif clave == DESPISTE and combatiente.esta_enamorado:
			combatiente.esta_enamorado = false
			combatiente.target_enamorado = null
			acciones.append(AccionHabilidad.mensaje("¡%s de %s\ncuró su problema de ENAMORAMIENTO!" % [nombre(clave), _n(pokemon)]))
	if not HABILIDAD_CONTRA_ESTADO.has(clave):
		return acciones
	var estados: Array = HABILIDAD_CONTRA_ESTADO[clave]
	if estados.has(int(pokemon.estado)):
		var previo: int = pokemon.estado
		pokemon.estado = Singleton.ProblemaEstado.NORMAL
		acciones.append(AccionHabilidad.estado(pokemon, "¡%s de %s\ncuró su problema de %s!" % [nombre(clave), _n(pokemon), str(NOMBRES_ESTADO.get(previo, "estado"))]))
	return acciones


## true si AUSENTE obliga al Pokémon a holgazanear este turno.
static func holgazanea(pokemon: BasePokemon, combatiente: PokemonEnCombate) -> bool:
	return tiene(pokemon, AUSENTE) and combatiente != null and combatiente.holgazaneando


# ─── Salida del campo ────────────────────────────────────────────────────────

## atkE2_switchoutabilities: CURA NATURAL cura el estado al retirarse. Después
## quita lo que era solo de combate. No muestra mensaje (como en la ROM).
static func al_salir(pokemon: BasePokemon) -> void:
	if pokemon == null:
		return
	if tiene(pokemon, CURANATURAL) and _con_estado(pokemon):
		pokemon.estado = Singleton.ProblemaEstado.NORMAL
	limpiar_combate(pokemon)


# ─── Daño ────────────────────────────────────────────────────────────────────

## Estadística ofensiva con las habilidades de atacante y defensor
## (CalculateBaseDamage). `categoria`: 1 físico, 2 especial.
static func ataque_modificado(atacante: BasePokemon, defensor: BasePokemon, categoria: int, ataque: float, tipo_mov: String, campo: CampoCombate = null) -> float:
	var propia := de(atacante)
	if categoria != 2:
		if propia == POTENCIA or propia == ENERGIAPURA:
			ataque *= 2.0
		if propia == ENTUSIASMO:
			ataque = floorf(150.0 * ataque / 100.0)
		if propia == AGALLAS and _con_estado(atacante):
			ataque = floorf(150.0 * ataque / 100.0)
	elif campo != null:
		if (propia == MAS and campo.hay_habilidad(MENOS)) or (propia == MENOS and campo.hay_habilidad(MAS)):
			ataque = floorf(150.0 * ataque / 100.0)
	if tiene(defensor, SEBO) and (tipo_mov == "FUEGO" or tipo_mov == "HIELO"):
		ataque = floorf(ataque / 2.0)
	return ataque


## Estadística defensiva: ESCAMA ESPECIAL ×1.5 (solo físico) con un estado.
static func defensa_modificada(defensor: BasePokemon, categoria: int, defensa: float) -> float:
	if categoria != 2 and tiene(defensor, ESCAMAESPECIAL) and _con_estado(defensor):
		return floorf(150.0 * defensa / 100.0)
	return defensa


## Potencia con ESPESURA / MAR LLAMAS / TORRENTE / ENJAMBRE: ×1.5 del tipo
## correspondiente con PS <= 1/3 del máximo (división entera).
static func potencia_modificada(atacante: BasePokemon, tipo_mov: String, potencia: float) -> float:
	var clave := de(atacante)
	if HABILIDADES_APURO.get(clave, "") == tipo_mov \
			and atacante.estad_ps_actual <= atacante.estad_ps / 3:
		return floorf(150.0 * potencia / 100.0)
	return potencia


## ABSORBE FUEGO ya activado: los ataques de fuego del Pokémon ×1.5.
static func multiplicador_absorbe_fuego(combatiente: PokemonEnCombate, tipo_mov: String) -> float:
	return 1.5 if combatiente != null and combatiente.absorbe_fuego and tipo_mov == "FUEGO" else 1.0


## false con AGALLAS: la quemadura no reduce su ataque a la mitad.
static func reduce_ataque_por_quemadura(pokemon: BasePokemon) -> bool:
	return pokemon.estado == Singleton.ProblemaEstado.QUEMADO and not tiene(pokemon, AGALLAS)


# ─── Inmunidades al ser atacado ──────────────────────────────────────────────

## ABILITYEFFECT_MOVES_BLOCK / ABSORBING / Levitación / SUPERGUARDA. Devuelve
## las acciones si la habilidad del defensor anula el movimiento (no vacía =
## bloqueado) o `[]` si el movimiento sigue su curso. `efectividad`: la del tipo.
static func bloquear_movimiento(atacante: BasePokemon, defensor: BasePokemon, movimiento: Movimiento, efectividad: float, combatiente_defensor: PokemonEnCombate = null) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if atacante == defensor or movimiento == null:
		return acciones
	var clave := de(defensor)
	if clave.is_empty():
		return acciones
	var tipo := movimiento.get_tipo()
	var con_potencia := movimiento.get_potencia() > 0
	var nom := nombre(clave)
	var def_n := _n(defensor)

	if clave == INSONORIZAR and movimiento.es_sonoro():
		acciones.append(AccionHabilidad.mensaje("¡%s de %s\nhace %s inefectivo!" % [nom, def_n, movimiento.nombre]))
		return acciones
	if clave == LEVITACION and tipo == "TIERRA" and (con_potencia or EfectosGolpe.es_ko_directo(movimiento)):
		acciones.append(AccionHabilidad.mensaje("¡%s impide ataques\nde TIERRA con %s!" % [def_n, nom]))
		return acciones
	if (clave == ABSORBEELEC and tipo == "ELECTRICO" and con_potencia) \
			or (clave == ABSORBEAGUA and tipo == "AGUA" and con_potencia):
		if defensor.estad_ps_actual >= defensor.estad_ps:
			acciones.append(AccionHabilidad.mensaje("¡%s de %s\nhace %s inútil!" % [nom, def_n, movimiento.nombre]))
		else:
			var cura := maxi(1, defensor.estad_ps / 4)
			acciones.append(AccionHabilidad.curar(defensor, cura, "¡%s restauró PS\ncon %s!" % [def_n, nom]))
		return acciones
	if clave == ABSORBEFUEGO and tipo == "FUEGO" and defensor.estado != Singleton.ProblemaEstado.CONGELADO:
		if combatiente_defensor != null and not combatiente_defensor.absorbe_fuego:
			combatiente_defensor.absorbe_fuego = true
			acciones.append(AccionHabilidad.mensaje("¡%s de %s\naumenta su poder de FUEGO!" % [nom, def_n]))
		else:
			acciones.append(AccionHabilidad.mensaje("¡%s de %s\nhace %s inútil!" % [nom, def_n, movimiento.nombre]))
		return acciones
	if clave == SUPERGUARDA and con_potencia and efectividad <= 1.0:
		acciones.append(AccionHabilidad.mensaje("¡%s se protegió\ncon %s!" % [def_n, nom]))
		return acciones
	return acciones


# ─── Precisión y velocidad ───────────────────────────────────────────────────

## Precisión efectiva tras OJO COMPUESTO ×1.3, VELO ARENA ×0.8 (tormenta de
## arena) y ENTUSIASMO ×0.8 (físicos). Un valor < 0 (siempre acierta) no cambia.
static func precision_modificada(precision: int, atacante: BasePokemon, defensor: BasePokemon, movimiento: Movimiento, campo: CampoCombate = null) -> int:
	if precision < 0:
		return precision
	if tiene(atacante, OJOCOMPUESTO):
		precision = precision * 130 / 100
	if campo != null and tiene(defensor, VELOARENA) and campo.clima_efectivo() == Singleton.ClimaBatalla.TORMENTA_ARENA:
		precision = precision * 80 / 100
	if tiene(atacante, ENTUSIASMO) and movimiento != null and movimiento.get_categoria_dano_id() == 1:
		precision = precision * 80 / 100
	return precision


## NADO RÁPIDO (lluvia) y CLOROFILA (sol) duplican la velocidad.
static func velocidad_modificada(pokemon: BasePokemon, velocidad: int, clima_efectivo: int) -> int:
	var clave := de(pokemon)
	if (clave == NADORAPIDO and clima_efectivo == Singleton.ClimaBatalla.LLUVIA) \
			or (clave == CLOROFILA and clima_efectivo == Singleton.ClimaBatalla.SOLEADO):
		return velocidad * 2
	return velocidad


# ─── Estados ─────────────────────────────────────────────────────────────────

## Habilidad del objetivo que impide recibir `estado` (Singleton.ProblemaEstado)
## o "". INMUNIDAD (veneno), FLEXIBILIDAD (parálisis), INSOMNIO / ESPÍRITU
## VITAL (sueño), VELO AGUA (quemadura), ESCUDO MAGMA (congelación).
static func habilidad_que_impide_estado(objetivo: BasePokemon, estado: int) -> String:
	var clave := de(objetivo)
	if HABILIDAD_CONTRA_ESTADO.has(clave) and (HABILIDAD_CONTRA_ESTADO[clave] as Array).has(estado):
		return clave
	return ""


## Mensaje de la ROM cuando la habilidad impide el estado.
static func mensaje_impide_estado(objetivo: BasePokemon, estado: int) -> String:
	var clave := habilidad_que_impide_estado(objetivo, estado)
	if clave.is_empty():
		return ""
	var nom := nombre(clave)
	match estado:
		ESTADO_ENVENENADO:
			return "¡%s de %s\nevita el envenenamiento!" % [nom, _n(objetivo)]
		ESTADO_PARALIZADO:
			return "¡%s de %s\nevita la parálisis!" % [nom, _n(objetivo)]
		ESTADO_QUEMADO:
			return "¡%s de %s\nevita las quemaduras!" % [nom, _n(objetivo)]
		ESTADO_DORMIDO:
			return "¡%s se mantiene despierto\nusando %s!" % [_n(objetivo), nom]
		ESTADO_CONGELADO:
			return "¡%s de %s\nevita la congelación!" % [nom, _n(objetivo)]
	return ""


## true si el tipo del objetivo lo hace inmune a `estado` (quemar a FUEGO,
## envenenar a VENENO / ACERO, congelar a HIELO).
static func inmune_por_tipo(objetivo: BasePokemon, estado: int) -> bool:
	var tipos: Array[String] = BattleTransformRules.types(objetivo)
	match estado:
		ESTADO_QUEMADO:
			return tipos.has("FUEGO")
		ESTADO_ENVENENADO:
			return tipos.has("VENENO") or tipos.has("ACERO")
		ESTADO_CONGELADO:
			return tipos.has("HIELO")
	return false


## SINCRONÍA: si `receptor` (con SINCRONÍA) recibe veneno, quemadura o parálisis
## de `causante`, este recibe el mismo estado (si puede). Aplica el estado y
## devuelve las acciones; `[]` si no corresponde.
static func sincronizar(receptor: BasePokemon, causante: BasePokemon, estado: int, combatiente_de: Callable = Callable()) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if causante == null or causante == receptor or not tiene(receptor, SINCRONIA):
		return acciones
	if estado != ESTADO_ENVENENADO and estado != ESTADO_QUEMADO and estado != ESTADO_PARALIZADO:
		return acciones
	if causante.estad_ps_actual <= 0 or causante.estado != Singleton.ProblemaEstado.NORMAL:
		return acciones
	if not habilidad_que_impide_estado(causante, estado).is_empty() or inmune_por_tipo(causante, estado):
		return acciones
	causante.estado = estado
	var nom := nombre(SINCRONIA)
	var verbo: String = {ESTADO_ENVENENADO: "envenenó a", ESTADO_QUEMADO: "quemó a", ESTADO_PARALIZADO: "paralizó a"}[estado]
	acciones.append(AccionHabilidad.estado(causante, "¡%s de %s\n%s %s!" % [nom, _n(receptor), verbo, _n(causante)]))
	return acciones


# ─── Tras recibir un golpe ───────────────────────────────────────────────────

## ABILITYEFFECT_CONTACT: lo que ocurre después de que `defensor` encaje un
## golpe de `atacante` que le hizo `dano` PS. PIEL TOSCA, ELEC. ESTÁT., CUERPO
## LLAMA, PUNTO TÓXICO, EFEC. ESPORA y GRAN ENCANTO exigen movimiento de contacto;
## CAMBIO COLOR no. Los estados de las habilidades de contacto respetan las
## inmunidades por habilidad y por tipo y activan SINCRONÍA.
static func tras_golpe(atacante: BasePokemon, defensor: BasePokemon, movimiento: Movimiento, dano: int, combatiente_de: Callable = Callable(), sortear: Callable = Callable()) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if atacante == null or defensor == null or movimiento == null or dano <= 0 or atacante == defensor:
		return acciones
	var clave := de(defensor)
	if clave.is_empty():
		return acciones
	var nom := nombre(clave)
	var def_n := _n(defensor)

	if clave == CAMBIOCOLOR and defensor.estad_ps_actual > 0 and movimiento.get_potencia() > 0:
		var tipo := movimiento.get_tipo()
		var tipos: Array[String] = BattleTransformRules.types(defensor)
		if not tipos.has(tipo) and not tipo.is_empty():
			if not BattleTransformRules.set_types(defensor,tipo,tipo):
				if defensor.tipos_originales_combate.is_empty():
					defensor.tipos_originales_combate = [defensor.tipo_1, defensor.tipo_2]
				defensor.tipo_1 = tipo
				defensor.tipo_2 = tipo
			acciones.append(AccionHabilidad.mensaje("¡%s de %s lo\nconvirtió en el tipo %s!" % [nom, def_n, tipo]))
		return acciones

	if not movimiento.hace_contacto() or atacante.estad_ps_actual <= 0:
		return acciones

	match clave:
		PIELTOSCA:
			var golpe := maxi(1, atacante.estad_ps / 16)
			acciones.append(AccionHabilidad.dano(atacante, golpe, "¡%s de %s\nhiere a %s!" % [nom, def_n, _n(atacante)]))
		ELECESTATICA:
			if _sortear(3, sortear) == 0:
				acciones.append_array(_estado_por_contacto(atacante, defensor, ESTADO_PARALIZADO, clave, combatiente_de))
		CUERPOLLAMA:
			if _sortear(3, sortear) == 0:
				acciones.append_array(_estado_por_contacto(atacante, defensor, ESTADO_QUEMADO, clave, combatiente_de))
		PUNTOTOXICO:
			if _sortear(3, sortear) == 0:
				acciones.append_array(_estado_por_contacto(atacante, defensor, ESTADO_ENVENENADO, clave, combatiente_de))
		EFECTOESPORA:
			if _sortear(10, sortear) == 0:
				var elegido: int = [ESTADO_DORMIDO, ESTADO_ENVENENADO, ESTADO_PARALIZADO][_sortear(3, sortear)]
				acciones.append_array(_estado_por_contacto(atacante, defensor, elegido, clave, combatiente_de))
		GRANENCANTO:
			if defensor.estad_ps_actual > 0 and _sortear(3, sortear) == 0:
				acciones.append_array(_enamorar(atacante, defensor, combatiente_de))
	return acciones


static func _estado_por_contacto(victima: BasePokemon, portador: BasePokemon, estado: int, clave: String, combatiente_de: Callable) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if victima.estado != Singleton.ProblemaEstado.NORMAL:
		return acciones
	if not habilidad_que_impide_estado(victima, estado).is_empty() or inmune_por_tipo(victima, estado):
		return acciones
	victima.estado = estado
	if estado == ESTADO_DORMIDO:
		var propio: PokemonEnCombate = combatiente_de.call(victima) if combatiente_de.is_valid() else null
		if propio != null:
			propio.iniciar_sueno()
	var verbo: String = {
		ESTADO_DORMIDO: "durmió a",
		ESTADO_ENVENENADO: "envenenó a",
		ESTADO_QUEMADO: "quemó a",
		ESTADO_PARALIZADO: "paralizó a",
		ESTADO_CONGELADO: "congeló a",
	}[estado]
	acciones.append(AccionHabilidad.estado(victima, "¡%s de %s\n%s %s!" % [nombre(clave), _n(portador), verbo, _n(victima)]))
	acciones.append_array(sincronizar(victima, portador, estado, combatiente_de))
	return acciones


## true si `a` y `b` tienen sexos opuestos (ninguno sin sexo).
static func sexos_opuestos(a: BasePokemon, b: BasePokemon) -> bool:
	return (a.sexo == "M" and b.sexo == "F") or (a.sexo == "F" and b.sexo == "M")


## Shared volatile authority for Cute Charm and an actual Attract move.
## Uses the domain gender field; source personality-derived gender parity is separate.
static func apply_infatuation(victim: BasePokemon,holder: BasePokemon,state: PokemonEnCombate) -> bool:
	if victim==null or holder==null or state==null or state.esta_enamorado:return false
	if tiene(victim,DESPISTE) or not sexos_opuestos(victim,holder):return false
	state.esta_enamorado=true;state.target_enamorado=holder
	return true

static func _enamorar(victima: BasePokemon, portador: BasePokemon, combatiente_de: Callable) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	var propio: PokemonEnCombate = combatiente_de.call(victima) if combatiente_de.is_valid() else null
	if not apply_infatuation(victima,portador,propio):return acciones
	acciones.append(AccionHabilidad.mensaje("¡%s de %s\nengañó a %s!" % [nombre(GRANENCANTO), _n(portador), _n(victima)]))
	return acciones


# ─── Presión, huida y cambio ─────────────────────────────────────────────────

## PP extra que cuesta usar un movimiento: 1 por cada objetivo (distinto del
## usuario) con PRESIÓN.
static func pp_extra_por_presion(atacante: BasePokemon, objetivos: Array) -> int:
	var extra := 0
	for objetivo in objetivos:
		if objetivo is BasePokemon and objetivo != atacante and tiene(objetivo, PRESION):
			extra += 1
	return extra


## Quién impide huir (o cambiar, `para_cambio`): {"bloqueador": BasePokemon,
## "habilidad": String} o {} si nadie. FUGA permite huir siempre (no cambiar).
## SOMBRA TRAMPA atrapa a todos; TRAMPA ARENA a los que no levitan ni vuelan;
## IMÁN a los de tipo ACERO.
static func impide_huida(huyente: BasePokemon, campo: CampoCombate, para_cambio: bool = false) -> Dictionary:
	if huyente == null:
		return {}
	if not para_cambio and tiene(huyente, FUGA):
		return {}
	var wrapped: Dictionary=preload("res://scripts/battle/turn_trap_rules.gd").blocked(huyente,campo)
	if not wrapped.is_empty():return wrapped
	var source_trap: Dictionary=preload("res://scripts/battle/escape_prevention_rules.gd").blocked(huyente,campo)
	if not source_trap.is_empty():return source_trap
	# STATUS3_ROOTED (ARRAIGO) también impide huir y cambiar.
	var enraizado: PokemonEnCombate=campo.combatiente_de.call(huyente) if campo.combatiente_de.is_valid() else null
	if enraizado!=null and enraizado.source_ingrain_rooted:return {"bloqueador":huyente,"source_move":275}
	var tipos: Array[String] = BattleTransformRules.types(huyente)
	for rival in campo.rivales_de(huyente):
		var clave := de(rival)
		if clave == SOMBRATRAMPA:
			return {"bloqueador": rival, "habilidad": clave}
		if clave == TRAMPAARENA and not tiene(huyente, LEVITACION) and not tipos.has("VOLADOR"):
			return {"bloqueador": rival, "habilidad": clave}
		if clave == IMAN and tipos.has("ACERO"):
			return {"bloqueador": rival, "habilidad": clave}
	return {}


static func mensaje_impide_huida(info: Dictionary, para_cambio: bool = false) -> String:
	if info.is_empty():
		return ""
	var bloqueador: BasePokemon = info["bloqueador"]
	if info.has("source_move"):
		var move_name: String={169:"La telaraña",212:"Mal de ojo",275:"Arraigo",335:"Bloqueo"}.get(int(info.source_move),"El movimiento")
		return "¡%s de %s\nimpide escapar!"%[move_name,_n(bloqueador)]
	var nom := nombre(str(info["habilidad"]))
	if para_cambio:
		return "¡%s de %s\nevita el cambio!" % [nom, _n(bloqueador)]
	return "¡%s impide la\nhuida con %s!" % [_n(bloqueador), nom]


## PARARRAYOS (solo combates dobles): un movimiento ELÉCTRICO de un solo
## objetivo se desvía al rival con PARARRAYOS. Devuelve el nuevo objetivo, o
## null si no hay desvío. Una nueva acción de texto la monta quien llama.
## Ruby (battle_main.c, elección de gBattlerTarget) solo mira portadores del
## lado contrario al atacante y no exige que el objetivo elegido sea rival:
## un ataque eléctrico al compañero también lo atrae el PARARRAYOS rival. Solo
## se salta si el elegido ya tiene PARARRAYOS o es el propio usuario (CARGA).
static func redirigir_ataque_electrico(atacante: BasePokemon, objetivo: BasePokemon, movimiento: Movimiento, campo: CampoCombate) -> BasePokemon:
	if atacante == null or objetivo == null or movimiento == null or movimiento.get_tipo() != "ELECTRICO":
		return null
	if tiene(objetivo, PARARRAYOS) or objetivo == atacante:
		return null
	for rival in campo.rivales_de(atacante):
		if rival != objetivo and tiene(rival, PARARRAYOS):
			return rival
	return null


static func mensaje_pararrayos(portador: BasePokemon) -> String:
	return "¡%s de %s\ntomó el ataque!" % [nombre(PARARRAYOS), _n(portador)]


## FUGA garantiza la huida de un salvaje / del jugador (battle_main.c 5471).
static func huida_garantizada(pokemon: BasePokemon) -> bool:
	return tiene(pokemon, FUGA)


# ─── Sueño y movimientos ─────────────────────────────────────────────────────

## Turnos de sueño que se descuentan por turno: MADRUGAR descuenta 2.
static func reduccion_sueno(pokemon: BasePokemon) -> int:
	return 2 if tiene(pokemon, MADRUGAR) else 1


## Un movimiento sonoro lo detiene INSONORIZAR del objetivo.
static func es_bloqueado_por_sonido(defensor: BasePokemon, movimiento: Movimiento) -> bool:
	return tiene(defensor, INSONORIZAR) and movimiento != null and movimiento.es_sonoro()


# ─── Consultas puntuales ─────────────────────────────────────────────────────
# Las usan `EfectosGolpe` (críticos, efectos secundarios, retroceso, drenaje,
# autodestrucción, K.O. de un golpe, robo de objeto, confusión) y el controlador
# de turno (cambio forzado).

## ARMADURA BATALLA / CAPARAZÓN: los golpes críticos no le afectan.
static func evita_critico(defensor: BasePokemon) -> bool:
	return tiene(defensor, ARMADURABATALLA) or tiene(defensor, CAPARAZON)


## POLVO ESCUDO: ignora los efectos secundarios de los ataques que recibe.
static func ignora_efecto_secundario(defensor: BasePokemon) -> bool:
	return tiene(defensor, POLVOESCUDO)


## DICHA duplica la probabilidad de los efectos secundarios de sus ataques.
static func probabilidad_efecto_secundario(atacante: BasePokemon, base: int) -> int:
	return base * 2 if tiene(atacante, DICHA) else base


## FOCO INTERNO impide el retroceso.
static func evita_retroceso(defensor: BasePokemon) -> bool:
	return tiene(defensor, FOCOINTERNO)


## RITMO PROPIO impide la confusión.
static func evita_confusion(defensor: BasePokemon) -> bool:
	return tiene(defensor, RITMOPROPIO)


## DESPISTE impide enamorarse.
static func evita_enamoramiento(defensor: BasePokemon) -> bool:
	return tiene(defensor, DESPISTE)


## VENTOSAS impide que lo cambien a la fuerza (Remolino, Rugido).
static func evita_cambio_forzado(defensor: BasePokemon) -> bool:
	return tiene(defensor, VENTOSAS)


## VISCOSIDAD impide que le roben el objeto.
static func evita_robo_objeto(defensor: BasePokemon) -> bool:
	return tiene(defensor, VISCOSIDAD)


## CABEZA ROCA: sin daño de retroceso.
static func evita_dano_retroceso(atacante: BasePokemon) -> bool:
	return tiene(atacante, CABEZAROCA)


## HUMEDAD: si alguien la tiene en el campo, no se puede autodestruir nadie.
static func bloquea_autodestruccion(campo: CampoCombate) -> bool:
	return campo.hay_habilidad(HUMEDAD)


## LODO LÍQUIDO: los movimientos de drenaje le hacen daño a quien los usa.
static func invierte_drenaje(defensor: BasePokemon) -> bool:
	return tiene(defensor, LODOLIQUIDO)


## ROBUSTEZ: inmune a los movimientos de K.O. de un golpe.
static func inmune_a_ko_directo(defensor: BasePokemon) -> bool:
	return tiene(defensor, ROBUSTEZ)


## CASTFORM_TO_*: forma de CASTFORM para su tipo (el `_n` de sus sprites); 0 = base.
static func forma_por_prediccion(tipo: String) -> int:
	return ["NORMAL", "FUEGO", "AGUA", "HIELO"].find(tipo)


## PREDICCIÓN (CASTFORM): tipo según el clima efectivo; "NORMAL" sin clima.
static func tipo_por_prediccion(clima_efectivo: int) -> String:
	match clima_efectivo:
		Singleton.ClimaBatalla.LLUVIA:
			return "AGUA"
		Singleton.ClimaBatalla.SOLEADO:
			return "FUEGO"
		Singleton.ClimaBatalla.GRANIZO:
			return "HIELO"
	return "NORMAL"
