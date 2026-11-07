extends RefCounted
class_name Guarderia

## Estado y reglas de la Guardería Pokémon de Ruta 117 (`src/daycare.c` de
## pokeruby), sin UI.
##
## Dependencias inyectadas (patrón `TallerVidrio`):
## - `datos`: responde a los métodos de `DatosCrianza` (duck-typing);
## - `rng`: `RandomNumberGenerator`, sembrable en los tests.
##
## Los ciclos que le faltan a un huevo se guardan en `BasePokemon.felicidad`,
## igual que en Rubí (`MON_DATA_FRIENDSHIP`).

const HUECOS: int = 2
const NIVEL_MAXIMO: int = 100
const NIVEL_HUEVO: int = 5  # EGG_HATCH_LEVEL
const FELICIDAD_ECLOSION: int = 120
const BOLA_HUEVO: String = "POKEBALL"
const GRUPO_NO_EGGS: String = "No Eggs"
const GRUPO_DITTO: String = "Ditto"
const INCIENSO_SUAVE: String = "INCIENSOSUAVE"
const INCIENSO_MARINO: String = "INCIENSOMARINO"
const BIT_MACHO: int = 0x8000
const ESPECIE_DITTO: String = "DITTO"

## Estados de `GetDaycareState`.
enum Estado { VACIA = 0, HUEVO_PENDIENTE = 1, UNO = 2, DOS = 3 }

## Claves de `dialogos.csv` de las frases de compatibilidad (`sCompatibilityMessages`).
const CLAVE_COMPAT_MUY_BIEN: String = "GUARDERIA_COMPAT_MUY_BIEN"
const CLAVE_COMPAT_BIEN: String = "GUARDERIA_COMPAT_BIEN"
const CLAVE_COMPAT_NO_GUSTAN: String = "GUARDERIA_COMPAT_NO_GUSTAN"
const CLAVE_COMPAT_OTROS: String = "GUARDERIA_COMPAT_OTROS"

## Orden de las estadísticas en `InheritIVs` (HP, ATK, DEF, SPEED, SPATK, SPDEF).
const IVS: Array[String] = [
	"iv_ps", "iv_ataque", "iv_defensa", "iv_velocidad", "iv_ataque_especial", "iv_defensa_especial",
]

## Los dos huecos de la guardería (`BasePokemon` o null).
var pokemon: Array = [null, null]
## Pasos dados desde que se dejó cada Pokémon (`steps[2]`).
var pasos: Array[int] = [0, 0]
## `pendingEggPersonality`: 0 = no hay huevo; si no, 1..0xFFFE.
var huevo_pendiente: int = 0
## `eggCycleStepsRemaining` (u8): contador global de pasos para los ciclos de huevo.
var contador_ciclo: int = 0

var datos: Object
var rng: RandomNumberGenerator
## Debug (no se guarda): el siguiente huevo sale sin tirada si hay compatibilidad.
var debug_forzar_huevo: bool = false


func _init(p_datos: Object = null, p_rng: RandomNumberGenerator = null) -> void:
	datos = p_datos if p_datos != null else DatosCrianza.new()
	if p_rng != null:
		rng = p_rng
	else:
		rng = RandomNumberGenerator.new()
		rng.randomize()


# ==============================================
# ESTADO
# ==============================================

## Número de Pokémon depositados (`CountPokemonInDaycare`).
func cantidad() -> int:
	var total := 0
	for poke in pokemon:
		if poke != null:
			total += 1
	return total


## `GetDaycareState`: 1 si hay huevo pendiente; si no, 0, 2 o 3.
func obtener_estado() -> int:
	if huevo_pendiente != 0:
		return Estado.HUEVO_PENDIENTE
	var total := cantidad()
	return total + 1 if total > 0 else Estado.VACIA


## Pokémon del hueco `i` o null.
func obtener_pokemon(i: int) -> BasePokemon:
	if i < 0 or i >= HUECOS:
		return null
	return pokemon[i]


# ==============================================
# DEPOSITAR Y RETIRAR
# ==============================================

## `StorePokemonInDaycare`: primer hueco libre, PP restaurados y pasos a 0.
## No acepta huevos ni un tercer Pokémon. La retirada del equipo la hace el llamador.
func depositar(poke: BasePokemon) -> bool:
	if poke == null or poke.huevo:
		return false
	var hueco := pokemon.find(null)
	if hueco < 0:
		return false
	for mov in poke.movimientos:
		if mov is Movimiento:
			mov.restaurar_pp()
	pokemon[hueco] = poke
	pasos[hueco] = 0
	return true


## Nivel que tendría el Pokémon del hueco `i` al retirarlo
## (`GetLevelAfterDaycareSteps`). 0 si el hueco está vacío.
func nivel_tras_pasos(i: int) -> int:
	var poke := obtener_pokemon(i)
	if poke == null:
		return 0
	return _nivel_para_experiencia(poke, poke.experiencia + pasos[i])


## Niveles ganados por los pasos (`GetNumLevelsGainedFromSteps`).
func niveles_ganados(i: int) -> int:
	var poke := obtener_pokemon(i)
	if poke == null:
		return 0
	return maxi(0, nivel_tras_pasos(i) - _nivel_para_experiencia(poke, poke.experiencia))


## `GetDaycareCostForSelectedMon`: 100 + 100 por nivel ganado.
func coste(i: int) -> int:
	return 100 + 100 * niveles_ganados(i)


## `TakeSelectedPokemonFromDaycare`: suma los pasos a la experiencia, sube
## nivel a nivel aprendiendo movimientos, recalcula estadísticas (el Pokémon sale
## curado, como `BoxMonToMon`) y desplaza el hueco 1 al 0 si hace falta.
## La inserción en el equipo la hace el llamador.
func retirar(i: int) -> BasePokemon:
	var poke := obtener_pokemon(i)
	if poke == null:
		return null

	if poke.nivel < NIVEL_MAXIMO:
		poke.experiencia += pasos[i]
		_aplicar_experiencia_guarderia(poke)
	_recalcular_estadisticas(poke)
	poke.estado = Singleton.ProblemaEstado.NORMAL

	pokemon[i] = null
	pasos[i] = 0
	_desplazar_huecos()
	return poke


## `Debug_AddDaycareSteps`: suma pasos a los dos huecos.
func debug_sumar_pasos(n: int) -> void:
	for i in range(HUECOS):
		pasos[i] += n


## Debug: el huevo pendiente aparece a los `n` pasos, sin tirada si hay
## compatibilidad. false si no hay dos Pokémon depositados.
func debug_huevo_en_pasos(n: int = 5) -> bool:
	if cantidad() < HUECOS:
		return false
	var resto := 255 - clampi(n, 1, 255)
	var base: int = pasos[1] - pasos[1] % 256
	pasos[1] = base + resto if pasos[1] % 256 <= resto else base + 256 + resto
	debug_forzar_huevo = true
	return true


## Debug: un huevo del equipo eclosiona a los `n` pasos. Devuelve cuántos huevos hay.
func debug_eclosion_en_pasos(equipo: Array, n: int = 5) -> int:
	var huevos := 0
	for poke in equipo:
		var huevo := poke as BasePokemon
		if huevo != null and huevo.huevo:
			huevo.felicidad = 0
			huevos += 1
	if huevos > 0:
		contador_ciclo = 255 - clampi(n, 1, 255)
	return huevos


# ==============================================
# COMPATIBILIDAD
# ==============================================

## `GetDaycareCompatibilityScore`: 0, 20, 50 o 70.
func compatibilidad() -> int:
	if cantidad() < HUECOS:
		return 0
	var a: BasePokemon = pokemon[0]
	var b: BasePokemon = pokemon[1]
	var grupos_a: Array = datos.grupos_huevo(a.nombre_interno)
	var grupos_b: Array = datos.grupos_huevo(b.nombre_interno)
	var mismo_eo := _mismo_entrenador(a, b)

	if grupos_a.has(GRUPO_NO_EGGS) or grupos_b.has(GRUPO_NO_EGGS):
		return 0
	var ditto_a := grupos_a.has(GRUPO_DITTO)
	var ditto_b := grupos_b.has(GRUPO_DITTO)
	if ditto_a and ditto_b:
		return 0
	if ditto_a or ditto_b:
		return 20 if mismo_eo else 50

	if a.sexo == b.sexo or _sin_sexo(a) or _sin_sexo(b):
		return 0
	var comparten := false
	for grupo in grupos_a:
		if grupos_b.has(grupo):
			comparten = true
			break
	if not comparten:
		return 0

	if a.nombre_interno == b.nombre_interno:
		return 50 if mismo_eo else 70
	return 20 if mismo_eo else 50


## Clave de `dialogos.csv` de la frase de compatibilidad (`SetDaycareCompatibilityString`).
func clave_texto_compatibilidad() -> String:
	match compatibilidad():
		70:
			return CLAVE_COMPAT_MUY_BIEN
		50:
			return CLAVE_COMPAT_BIEN
		20:
			return CLAVE_COMPAT_NO_GUSTAN
	return CLAVE_COMPAT_OTROS


# ==============================================
# PASOS Y HUEVOS
# ==============================================

## `_ShouldEggHatch`, llamado en cada paso del jugador. Suma pasos, decide si
## aparece un huevo y descuenta ciclos de los huevos del equipo.
## Devuelve el índice del huevo que eclosiona o -1.
func procesar_paso(equipo: Array) -> int:
	var padres := 0
	for i in range(HUECOS):
		if pokemon[i] != null:
			pasos[i] += 1
			padres += 1

	if huevo_pendiente == 0 and padres == HUECOS and pasos[1] % 256 == 255 \
			and ((debug_forzar_huevo and compatibilidad() > 0) or compatibilidad() > rng.randi_range(0, 99)):
		huevo_pendiente = rng.randi_range(1, 0xFFFE)
		debug_forzar_huevo = false

	# u8: 0..255; el ciclo se procesa al llegar a 255 (cada 256 pasos).
	contador_ciclo = (contador_ciclo + 1) % 256
	if contador_ciclo == 255:
		for i in range(equipo.size()):
			var poke: BasePokemon = equipo[i] as BasePokemon
			if poke == null or not poke.huevo:
				continue
			if poke.felicidad <= 0:
				return i
			poke.felicidad -= 1
	return -1


## `_GiveEggFromDaycare`: construye el huevo de los dos Pokémon depositados y
## limpia el huevo pendiente. La inserción en el equipo la hace el llamador.
func generar_huevo() -> BasePokemon:
	if cantidad() < HUECOS:
		return null

	# DetermineEggSpeciesAndParentSlots: [madre, padre].
	var especies: Array[String] = []
	var ranuras: Array[int] = [0, 1]
	for i in range(HUECOS):
		var poke: BasePokemon = pokemon[i]
		especies.append(poke.nombre_interno)
		if _es_ditto(poke):
			ranuras = [i ^ 1, i]
		elif poke.sexo == "F":
			ranuras = [i, i ^ 1]

	var especie: String = datos.especie_base(especies[ranuras[0]])
	if especie == "NIDORAN_F" and (huevo_pendiente & BIT_MACHO) != 0:
		especie = "NIDORAN_M"
	if especie == "ILLUMISE" and (huevo_pendiente & BIT_MACHO) != 0:
		especie = "VOLBEAT"

	# Si el Ditto hace de padre y el otro no es hembra, el Ditto pasa a ser la madre.
	if _es_ditto(pokemon[ranuras[1]]) and (pokemon[ranuras[0]] as BasePokemon).sexo != "F":
		ranuras = [ranuras[1], ranuras[0]]

	especie = _alterar_especie_con_incienso(especie)
	var huevo := crear_huevo(especie)
	if huevo == null:
		return null
	_heredar_ivs(huevo)
	_construir_movimientos_huevo(huevo, pokemon[ranuras[1]], pokemon[ranuras[0]])
	# SetInitialEggData: personalidad = huevo pendiente | (Random() << 16). Se
	# tira después de heredar los IV para no alterar su secuencia del RNG.
	huevo.personalidad = (huevo_pendiente & 0xFFFF) | ((rng.randi() & 0xFFFF) << 16)
	huevo.asignar_habilidad_por_personalidad()
	rechazar_huevo()
	return huevo


## `RemoveEggFromDayCare`: el huevo pendiente se pierde.
func rechazar_huevo() -> void:
	huevo_pendiente = 0
	contador_ciclo = 0


## `SetInitialEggData`/`CreateEgg`: huevo de nivel 5 con los ciclos de la
## especie en `felicidad`, Poké Ball y nivel de encuentro 0. El EO es el
## jugador si `SistemaGuardado` está disponible.
func crear_huevo(especie: String) -> BasePokemon:
	var huevo := BasePokemon.new(especie, NIVEL_HUEVO)
	if huevo.nombre == "":
		push_warning("[Guarderia] Especie de huevo '%s' no encontrada" % especie)
		return null
	# GiveBoxMonInitialMoveset: movimientos por nivel hasta el 5, en orden.
	huevo.movimientos = [] as Array[Movimiento]
	for entrada in datos.movimientos_nivel(especie):
		if int(entrada["nivel"]) <= NIVEL_HUEVO:
			_dar_movimiento(huevo, str(entrada["mov"]))
	huevo.huevo = true
	huevo.mote = ""
	huevo.felicidad = datos.ciclos_huevo(especie)
	huevo.encuentro_nivel = 0
	huevo.encuentro_bola = BOLA_HUEVO
	huevo.encuentro_lugar = Lugares.GUARDERIA_POKEMON
	huevo.encuentro_fatidico = false
	_asignar_jugador(huevo)
	return huevo


## Datos del recién nacido (`egg_hatch.c`, `CreatedHatchedMon`). No registra la
## Pokédex: lo hace el llamador.
func eclosionar(poke: BasePokemon, lugar: String) -> void:
	if poke == null:
		return
	poke.huevo = false
	poke.mote = ""
	poke.felicidad = FELICIDAD_ECLOSION
	poke.encuentro_nivel = 0
	poke.encuentro_bola = BOLA_HUEVO
	poke.encuentro_lugar = lugar
	poke.estado = Singleton.ProblemaEstado.NORMAL
	for mov in poke.movimientos:
		if mov is Movimiento:
			mov.restaurar_pp()
	_recalcular_estadisticas(poke)
	poke.estad_ps_actual = poke.estad_ps


# ==============================================
# SERIALIZACIÓN
# ==============================================

## Diccionario JSON: los Pokémon con el formato del equipo
## (`EstructuraGuardado._pokemon_a_diccionario`, movimientos incluidos).
func to_dict() -> Dictionary:
	var lista: Array = []
	for poke in pokemon:
		if poke is BasePokemon:
			lista.append(EstructuraGuardado._pokemon_a_diccionario(poke))
		else:
			lista.append(null)
	return {
		"pokemon": lista,
		"pasos": [pasos[0], pasos[1]],
		"huevo_pendiente": huevo_pendiente,
		"contador_ciclo": contador_ciclo,
	}


## Carga desde `to_dict()`. Un diccionario vacío deja la guardería vacía.
func from_dict(d: Dictionary) -> void:
	pokemon = [null, null]
	pasos = [0, 0]
	huevo_pendiente = int(d.get("huevo_pendiente", 0))
	contador_ciclo = int(d.get("contador_ciclo", 0))
	var lista: Variant = d.get("pokemon", [])
	var lista_pasos: Variant = d.get("pasos", [])
	for i in range(HUECOS):
		if lista is Array and i < (lista as Array).size() and lista[i] is Dictionary:
			pokemon[i] = EstructuraGuardado._diccionario_a_pokemon(lista[i])
		if lista_pasos is Array and i < (lista_pasos as Array).size():
			pasos[i] = int(lista_pasos[i])
	_desplazar_huecos()


# ==============================================
# INTERNOS
# ==============================================

## `ShiftDaycareSlots`.
func _desplazar_huecos() -> void:
	if pokemon[1] != null and pokemon[0] == null:
		pokemon[0] = pokemon[1]
		pokemon[1] = null
		pasos[0] = pasos[1]
		pasos[1] = 0


## Nivel que corresponde a `experiencia` según la curva de la especie (tope 100).
func _nivel_para_experiencia(poke: BasePokemon, experiencia: int) -> int:
	var nivel := 1
	while nivel < NIVEL_MAXIMO and experiencia >= datos.experiencia_nivel(poke.nombre_interno, nivel + 1):
		nivel += 1
	return nivel


## `ApplyDaycareExperience` (+ `TryIncrementMonLevel`, `MonTryLearningNewMove`).
func _aplicar_experiencia_guarderia(poke: BasePokemon) -> void:
	var tope: int = datos.experiencia_nivel(poke.nombre_interno, NIVEL_MAXIMO)
	if poke.experiencia > tope:
		poke.experiencia = tope
	while poke.nivel < NIVEL_MAXIMO \
			and poke.experiencia >= datos.experiencia_nivel(poke.nombre_interno, poke.nivel + 1):
		var nivel_antes := poke.nivel
		poke.subir_nivel()
		if poke.nivel == nivel_antes:
			break  # sin datos de especie: no se puede seguir
		for mov in datos.movimientos_en_nivel(poke.nombre_interno, poke.nivel):
			_dar_movimiento(poke, mov)
	poke.set_experiencia(poke.experiencia)


## `GiveMoveToMon` + `DeleteFirstMoveAndGiveMoveToMon`: si ya lo conoce no hace
## nada; con 4 movimientos borra el primero y añade el nuevo al final.
func _dar_movimiento(poke: BasePokemon, mov: String) -> void:
	if _conoce(poke, mov):
		return
	var nuevo: Movimiento = datos.crear_movimiento(mov)
	if nuevo == null:
		return
	if poke.movimientos.size() >= 4:
		poke.movimientos.remove_at(0)
	poke.movimientos.append(nuevo)


func _conoce(poke: BasePokemon, mov: String) -> bool:
	return _ids_movimientos(poke).has(mov)


func _ids_movimientos(poke: BasePokemon) -> Array[String]:
	var ids: Array[String] = []
	if poke == null:
		return ids
	for m in poke.movimientos:
		if m is Movimiento:
			ids.append(datos.id_movimiento(m))
	return ids


## `InheritIVs`: 3 estadísticas distintas, cada una de un hueco al azar.
func _heredar_ivs(huevo: BasePokemon) -> void:
	var disponibles: Array[int] = [0, 1, 2, 3, 4, 5]
	var elegidas: Array[int] = []
	for i in range(3):
		var indice := rng.randi_range(0, IVS.size() - 1 - i)
		elegidas.append(disponibles[indice])
		disponibles.remove_at(indice)
	var progenitores: Array[int] = []
	for i in range(3):
		progenitores.append(rng.randi_range(0, 1))
	for i in range(3):
		var propiedad: String = IVS[elegidas[i]]
		var progenitor: BasePokemon = pokemon[progenitores[i]]
		huevo.set(propiedad, int(progenitor.get(propiedad)))
	_recalcular_estadisticas(huevo)
	huevo.estad_ps_actual = huevo.estad_ps


## `BuildEggMoveset(egg, father, mother)`.
func _construir_movimientos_huevo(huevo: BasePokemon, padre: BasePokemon, madre: BasePokemon) -> void:
	var especie := huevo.nombre_interno
	var movs_padre := _ids_movimientos(padre)
	var movs_madre := _ids_movimientos(madre)
	var movs_huevo: Array = datos.movimientos_huevo(especie)

	# 1. Movimientos huevo que conoce el padre.
	for mov in movs_padre:
		if movs_huevo.has(mov):
			_dar_movimiento(huevo, mov)
	# 2. MT/MO del padre que la cría puede aprender.
	for mov in movs_padre:
		if datos.puede_aprender_mt(especie, mov):
			_dar_movimiento(huevo, mov)
	# 3. Movimientos comunes a padre y madre que la cría aprende por nivel.
	var comunes: Array[String] = []
	for mov in movs_padre:
		for mov_madre in movs_madre:
			if mov == mov_madre:
				comunes.append(mov)
	var por_nivel: Array[String] = []
	for entrada in datos.movimientos_nivel(especie):
		por_nivel.append(str(entrada["mov"]))
	for mov in comunes:
		if por_nivel.has(mov):
			_dar_movimiento(huevo, mov)


## `AlterEggSpeciesWithIncenseItem`: Wynaut y Azurill necesitan incienso.
func _alterar_especie_con_incienso(especie: String) -> String:
	if especie != "WYNAUT" and especie != "AZURILL":
		return especie
	var objetos: Array[String] = []
	for poke in pokemon:
		objetos.append(str((poke as BasePokemon).objeto).to_upper() if poke != null else "")
	if especie == "WYNAUT" and not objetos.has(INCIENSO_SUAVE):
		return "WOBBUFFET"
	if especie == "AZURILL" and not objetos.has(INCIENSO_MARINO):
		return "MARILL"
	return especie


## Recalcula estadísticas, Poder Oculto y experiencia del siguiente nivel.
## Deja los PS al máximo (`BoxMonToMon` + `CalculateMonStats`).
func _recalcular_estadisticas(poke: BasePokemon) -> void:
	poke._recalcular_stats_con_ivs_actuales()
	poke.tipo_poder_oculto = poke.get_poder_oculto(
		poke.iv_ps, poke.iv_ataque, poke.iv_defensa,
		poke.iv_velocidad, poke.iv_ataque_especial, poke.iv_defensa_especial)
	if poke.nivel < NIVEL_MAXIMO:
		poke.exp_sig_nivel = datos.experiencia_nivel(poke.nombre_interno, poke.nivel + 1)


func _mismo_entrenador(a: BasePokemon, b: BasePokemon) -> bool:
	return a.entrenador_id == b.entrenador_id and a.entrenador_original == b.entrenador_original


func _sin_sexo(poke: BasePokemon) -> bool:
	return poke.sexo != "M" and poke.sexo != "F"


func _es_ditto(poke: BasePokemon) -> bool:
	return poke != null and poke.nombre_interno == ESPECIE_DITTO


## El jugador como EO (`SistemaGuardado._asignar_jugador_como_entrenador_original`).
func _asignar_jugador(poke: BasePokemon) -> void:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null or arbol.root.get_node_or_null("SistemaGuardado") == null:
		return
	var jugador: Dictionary = SistemaGuardado.datos_vivos.jugador
	var nombre := str(jugador.get("nombre", "")).strip_edges()
	poke.entrenador_original = nombre if not nombre.is_empty() else "JUGADOR"
	poke.entrenador_id = int(jugador.get("id", 0))
	poke.entrenador_sexo = str(jugador.get("sexo", "M"))
