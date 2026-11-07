class_name Amistad
extends RefCounted

## Cambios de amistad por eventos (`AdjustFriendship`, `src/pokemon_3.c`).
##
## `BasePokemon.felicidad` guarda la amistad (0-255). En los huevos ese campo
## son los ciclos de eclosión, así que los huevos nunca se tocan aquí.

## FRIENDSHIP_EVENT_* (`include/pokemon.h`), en el mismo orden.
enum Evento {
	SUBIR_NIVEL,               ## GROW_LEVEL: subida de nivel en combate.
	VITAMINA,                  ## VITAMIN: MÁS PS, PROTEÍNA... (EfectosVitaminas).
	OBJETO_BATALLA,            ## BATTLE_ITEM. TODO: objetos X aún no se usan en combate.
	COMBATE_LIGA,              ## LEAGUE_BATTLE: combate contra LÍDER, ALTO MANDO o CAMPEÓN.
	MT_MO,                     ## LEARN_TMHM: cualquier MT/MO enseñada (EnsenanzaMaquina).
	PASEO,                     ## WALKING: cada 128 pasos, con un 50 % de probabilidad.
	DEBILITADO_LEVE,           ## FAINT_SMALL: debilitado por un rival de nivel superior.
	DEBILITADO_FUERA_BATALLA,  ## FAINT_OUTSIDE_BATTLE: debilitado por el veneno en el campo (VenenoCampo).
	DEBILITADO_GRAVE,          ## FAINT_LARGE: el rival le saca 30 niveles o más.
}

## sFriendshipEventDeltas: [amistad 0-99, 100-199, 200-255].
const DELTAS: Array = [
	[5, 3, 2],
	[5, 3, 2],
	[1, 1, 0],
	[3, 2, 1],
	[1, 1, 0],
	[1, 1, 1],
	[-1, -1, -1],
	[-5, -5, -10],
	[-5, -5, -10],
]

const AMISTAD_MAXIMA: int = 255
## Clases de entrenador que dan FRIENDSHIP_EVENT_LEAGUE_BATTLE
## (TRAINER_CLASS_LEADER, TRAINER_CLASS_ELITE_FOUR y TRAINER_CLASS_CHAMPION).
const CLASES_LIGA: Array[String] = ["LÍDER", "ALTO MANDO", "CAMPEÓN"]
## HOLD_EFFECT_HAPPINESS_UP (CASCABEL ALIVIO): x1,5 en los aumentos.
const OBJETO_CASCABEL_ALIVIO: String = "CASCABELALIVIO"
## ITEM_LUXURY_BALL: +1 extra en los aumentos.
const BOLA_LUJO: String = "LUJOBALL"
## VAR_HAPPINESS_STEP_COUNTER (SistemaGuardado.datos_persistentes.contadores).
const CONTADOR_PASOS: String = "pasos_amistad"
const PASOS_POR_CICLO: int = 128
## FAINT_LARGE si el rival le saca más de 29 niveles.
const DIFERENCIA_NIVEL_GRAVE: int = 29


## `AdjustFriendship`: aplica `evento` a `pokemon` y devuelve el cambio real.
## `lugar_actual` es la clave de Lugares de la zona actual (un +1 extra si es
## donde se encontró al Pokémon); "" = se averigua del mapa. `rng` solo se usa
## en PASEO (tirada del 50 %).
static func ajustar(pokemon: BasePokemon, evento: Evento, lugar_actual: String = "", rng: RandomNumberGenerator = null) -> int:
	if pokemon == null or pokemon.huevo or pokemon.nombre_interno.is_empty():
		return 0
	if evento == Evento.PASEO:
		var aleatorio: int = rng.randi() if rng != null else randi()
		if aleatorio & 1:
			return 0
	var antes := pokemon.felicidad
	var delta := int(DELTAS[evento][tramo(antes)])
	if delta > 0 and pokemon.objeto == OBJETO_CASCABEL_ALIVIO:
		delta = (150 * delta) / 100
	var nueva := antes + delta
	if delta > 0:
		if pokemon.encuentro_bola == BOLA_LUJO:
			nueva += 1
		var lugar := lugar_actual if not lugar_actual.is_empty() else _lugar_mapa_actual()
		if not lugar.is_empty() and pokemon.encuentro_lugar == lugar:
			nueva += 1
	pokemon.felicidad = clampi(nueva, 0, AMISTAD_MAXIMA)
	return pokemon.felicidad - antes


## Tramo de la tabla de deltas: 0 (0-99), 1 (100-199) o 2 (200-255).
static func tramo(amistad: int) -> int:
	if amistad > 199:
		return 2
	if amistad > 99:
		return 1
	return 0


## `UpdateHappinessStep`: cuenta el paso y cada 128 aplica PASEO a todo el equipo.
## Devuelve true en el paso que completa el ciclo.
static func procesar_paso(equipo: Array, rng: RandomNumberGenerator = null) -> bool:
	var pasos := (SistemaGuardado.get_contador(CONTADOR_PASOS) + 1) % PASOS_POR_CICLO
	SistemaGuardado.set_contador(CONTADOR_PASOS, pasos)
	if pasos != 0:
		return false
	var lugar := _lugar_mapa_actual()
	for poke in equipo:
		if poke is BasePokemon:
			ajustar(poke, Evento.PASEO, lugar, rng)
	return true


## LEAGUE_BATTLE al empezar un combate (`CB2_InitBattle`): todo el equipo, solo
## contra LÍDER, ALTO MANDO o CAMPEÓN.
static func aplicar_combate_liga(equipo: Array, clase_entrenador: String) -> void:
	if not CLASES_LIGA.has(clase_entrenador.strip_edges().to_upper()):
		return
	var lugar := _lugar_mapa_actual()
	for poke in equipo:
		if poke is BasePokemon:
			ajustar(poke, Evento.COMBATE_LIGA, lugar)


## `atk19_tryfaintmon`: el Pokémon del jugador se debilita ante un rival de
## nivel `nivel_rival`. Sin efecto si el rival no tiene más nivel.
static func aplicar_debilitado_en_combate(pokemon: BasePokemon, nivel_rival: int) -> void:
	if pokemon == null or nivel_rival <= pokemon.nivel:
		return
	var evento := Evento.DEBILITADO_GRAVE if nivel_rival - pokemon.nivel > DIFERENCIA_NIVEL_GRAVE else Evento.DEBILITADO_LEVE
	ajustar(pokemon, evento)


## `sav1_map_get_name`: sección (clave de Lugares) del mapa actual, o "".
static func _lugar_mapa_actual() -> String:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null:
		return ""
	var admin := arbol.root.get_node_or_null("AdministradorMapa")
	if admin == null or not admin.has_method("obtener_seccion_lugar_actual"):
		return ""
	return str(admin.obtener_seccion_lugar_actual())
